with Ada.Containers.Vectors;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   type Message_Id is private;
   type Author_Id is private;
   with function Author_Label (Author : Author_Id) return Wide_Wide_String;
   with function "=" (Left, Right : Message_Id) return Boolean is <>;
   Capacity : Positive;
package Flyology_TUI.Components.Chats is
   --  Chats is a task-free retained controller. One caller owns Model and
   --  serializes all updates. Producers may send detached values to that
   --  caller, but this package owns no task, queue, network, or callback.

   type Message_Role is (User, Assistant, System, Tool, Notice);
   type Delivery_State is
     (Pending, Streaming, Delivered, Failed, Cancelled);

   type Message is record
      Id       : Message_Id;
      Author   : Author_Id;
      Role     : Message_Role := User;
      Delivery : Delivery_State := Delivered;
      Sequence : Natural := 0;
   end record;
   type Message_Array is array (Positive range <>) of Message;

   type Measurement is record
      Id            : Message_Id;
      Body_Height   : Natural := 1;
      Action_Height : Natural := 0;
   end record;
   type Measurement_Array is array (Positive range <>) of Measurement;

   type Appearance is record
      Transcript : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Header     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      User_Bubble : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Assistant_Bubble : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      System_Bubble : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Tool_Bubble : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Notice_Bubble : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      User       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Assistant  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      System     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Tool       : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Notice     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Pending    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Streaming  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Failed     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Focused    : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Footer     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Composer   : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   subtype Message_Width_Percentage is Positive range 1 .. 100;
   type Message_Layout_Mode is (Dense_Transcript, Message_Bubbles);
   type Layout_Options is record
      Mode                  : Message_Layout_Mode := Dense_Transcript;
      Maximum_Message_Width : Natural := Natural'Last;
      Maximum_Percentage    : Message_Width_Percentage := 100;
      Horizontal_Padding    : Natural := 0;
      Message_Gap           : Natural := 0;
   end record;

   Dense_Layout : constant Layout_Options :=
     (Mode                  => Dense_Transcript,
      Maximum_Message_Width => Natural'Last,
      Maximum_Percentage    => 100,
      Horizontal_Padding    => 0,
      Message_Gap           => 0);
   Conversational_Layout : constant Layout_Options :=
     (Mode                  => Message_Bubbles,
      Maximum_Message_Width => 72,
      Maximum_Percentage    => 72,
      Horizontal_Padding    => 1,
      Message_Gap           => 1);

   type Model is tagged private;

   function Create
     (Messages      : Message_Array;
      Viewport_Rows : Natural := 12) return Model;

   --  Layout geometry is independent from Appearance and remains under the
   --  serial application owner's control. Dense_Layout preserves the original
   --  full-width transcript; Conversational_Layout adds readable bubbles.
   procedure Set_Layout
     (Item : in out Model; Options : Layout_Options);
   function Layout (Item : Model) return Layout_Options;

   --  Replacement validates capacity and duplicate ids before mutation.
   --  Measurements, focus, and selection follow surviving stable ids.
   --  New ids increment Unread_Count only while follow-tail is disabled.
   procedure Set_Messages
     (Item     : in out Model;
      Messages : Message_Array);

   --  Measurements must contain exactly one entry for every current message.
   --  Validation and height-overflow checks complete before Model changes.
   procedure Reconcile_Measurements
     (Item         : in out Model;
      Measurements : Measurement_Array);

   procedure Set_Viewport_Rows (Item : in out Model; Rows : Natural);
   function Viewport_Rows (Item : Model) return Natural;
   function Content_Height (Item : Model) return Natural;
   function First_Visible_Cell (Item : Model) return Natural;

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Contains (Item : Model; Id : Message_Id) return Boolean;
   function Message_At (Item : Model; Position : Positive) return Message
     with Pre => Position <= Length (Item);

   function Has_Focused_Message (Item : Model) return Boolean;
   function Focused_Id (Item : Model) return Message_Id
     with Pre => Has_Focused_Message (Item);
   function Has_Selection (Item : Model) return Boolean;
   function Selected_Id (Item : Model) return Message_Id
     with Pre => Has_Selection (Item);
   procedure Select_Id (Item : in out Model; Id : Message_Id);
   procedure Clear_Selection (Item : in out Model);

   procedure Set_Follow_Tail
     (Item    : in out Model;
      Enabled : Boolean := True);
   function Follows_Tail (Item : Model) return Boolean;
   function Unread_Count (Item : Model) return Natural;
   procedure Mark_All_Seen (Item : in out Model);

   --  Positive deltas move toward the tail; negative deltas move toward the
   --  start. Integer'First and other extreme values saturate safely.
   procedure Scroll_Cells
     (Item    : in out Model;
      Amount  : Integer;
      Changed : out Boolean);

   --  Layout planning allocates no Surface. It identifies the stable ids whose
   --  body/action surfaces Present will require for the current viewport.
   type Layout_Plan is private;

   function Plan
     (Item            : Model;
      Width           : Natural;
      Footer_Height   : Natural := 0;
      Composer_Height : Natural := 0) return Layout_Plan;

   function Width (Item : Layout_Plan) return Natural;
   function Height (Item : Layout_Plan) return Natural;
   function Transcript_Region
     (Item : Layout_Plan) return Flyology_TUI.Geometry.Rectangle;
   function Has_Footer (Item : Layout_Plan) return Boolean;
   function Footer_Region
     (Item : Layout_Plan) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Footer (Item);
   function Has_Composer (Item : Layout_Plan) return Boolean;
   function Composer_Region
     (Item : Layout_Plan) return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Composer (Item);

   function Required_Body_Count (Item : Layout_Plan) return Natural;
   function Required_Body_Id
     (Item : Layout_Plan; Position : Positive) return Message_Id
     with Pre => Position <= Required_Body_Count (Item);
   function Requires_Body
     (Item : Layout_Plan; Id : Message_Id) return Boolean;

   type Body_Entry is record
      Id      : Message_Id;
      Content : Flyology_TUI.Surfaces.Surface;
      Actions : Flyology_TUI.Surfaces.Surface;
   end record;
   type Body_Array is array (Positive range <>) of Body_Entry;

   --  Presentation borrows bodies, actions, footer, composer, and appearance.
   --  It retains only the composed frame, ids, and geometry. Bodies must have
   --  exactly the planned measured heights. Widths are clipped to the frame.
   type Presentation is private;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Footer    : Flyology_TUI.Surfaces.Surface;
      Composer  : Flyology_TUI.Surfaces.Surface;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Footer    : Flyology_TUI.Surfaces.Surface;
      Composer  : Flyology_TUI.Surfaces.Surface;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation;

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface;
   function Layout (Item : Presentation) return Layout_Plan;
   function Has_Message
     (Item : Presentation; Id : Message_Id) return Boolean;
   function Bubble_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Message (Item, Id);
   function Header_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Message (Item, Id);
   function Body_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Message (Item, Id);
   function Has_Action_Region
     (Item : Presentation; Id : Message_Id) return Boolean;
   function Action_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Action_Region (Item, Id);

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Events over body, action, footer, or composer regions are deliberately
   --  unconsumed so the caller can route them to heterogeneous children.
   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);
   procedure Update
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation);

private
   package Message_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Message);
   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Natural);
   package Integer_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Integer);
   package Id_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Message_Id,
      "="          => "=");
   package Region_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Flyology_TUI.Geometry.Rectangle,
      "="          => Flyology_TUI.Geometry."=");

   type Model is tagged record
      Messages       : Message_Vectors.Vector;
      Body_Heights   : Natural_Vectors.Vector;
      Action_Heights : Natural_Vectors.Vector;
      Focused        : Natural := 0;
      Selected       : Natural := 0;
      First_Cell     : Natural := 0;
      Rows           : Natural := 12;
      Follow_Tail    : Boolean := True;
      Unread         : Natural := 0;
      Options        : Layout_Options := Dense_Layout;
   end record;

   type Layout_Plan is record
      Frame_Width       : Natural := 0;
      Frame_Height      : Natural := 0;
      Transcript_Value  : Flyology_TUI.Geometry.Rectangle;
      Footer_Value      : Flyology_TUI.Geometry.Rectangle;
      Composer_Value    : Flyology_TUI.Geometry.Rectangle;
      Ids               : Id_Vectors.Vector;
      Header_Regions    : Region_Vectors.Vector;
      Body_Regions      : Region_Vectors.Vector;
      Action_Regions    : Region_Vectors.Vector;
      Bubble_Regions    : Region_Vectors.Vector;
      Body_Origins      : Integer_Vectors.Vector;
      Action_Origins    : Integer_Vectors.Vector;
   end record;

   type Presentation is record
      Frame_Value  : Flyology_TUI.Surfaces.Surface;
      Layout_Value : Layout_Plan;
   end record;
end Flyology_TUI.Components.Chats;
