with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Windows;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Skins;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;
with Interfaces;

generic
   type Pane_Id is (<>);
   Maximum_Panes : Positive;
   with function Label (Id : Pane_Id) return Wide_Wide_String;
package Flyology_TUI.Components.Dock_Workspaces is
   type Dock_Side is (Dock_Left, Dock_Right, Dock_Top, Dock_Bottom);
   type Pane_Placement is (Docked, Floating);

   type Pane_Definition is record
      Id             : Pane_Id := Pane_Id'First;
      Side           : Dock_Side := Dock_Left;
      Dock_Extent    : Positive := 20;
      Minimum_Extent : Positive := 4;
      Float_X        : Integer := 2;
      Float_Y        : Integer := 1;
      Float_Width    : Positive := 30;
      Float_Height   : Positive := 10;
      Initially_Floating  : Boolean := False;
      Initially_Collapsed : Boolean := False;
      Floatable      : Boolean := True;
      Collapsible    : Boolean := True;
   end record;

   type Pane_Definition_Array is
     array (Integer range <>) of Pane_Definition;
   type Surface_Array is
     array (Pane_Id range <>) of Flyology_TUI.Surfaces.Surface;

   type Appearance is record
      Workspace          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Dock               : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Header             : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Header     : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Rail               : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Rail       : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Action             : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Drop_Target        : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Disabled           : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Floating_Window    : Flyology_TUI.Components.Windows.Appearance;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;
   type Presentation is private;

   --  Configure a bounded workspace. Pane IDs and occupied dock sides must be
   --  unique. Initially floating panes remember Side as their return dock.
   --  Children, labels, and presentation styles remain caller-owned.
   function Create
     (Panes         : Pane_Definition_Array;
      Width, Height : Natural) return Model;

   --  Resize constrains floating windows and cancels semantic movement while
   --  preserving an already-acquired capture until matching left release.
   procedure Resize
     (Item          : in out Model;
      Width, Height : Natural);

   function Width (Item : Model) return Natural;
   function Height (Item : Model) return Natural;
   function Bounds (Item : Model) return Flyology_TUI.Geometry.Rectangle;
   function Pane_Count (Item : Model) return Natural;
   function Has_Pane (Item : Model; Id : Pane_Id) return Boolean;

   function Placement
     (Item : Model; Id : Pane_Id) return Pane_Placement
     with Pre => Has_Pane (Item, Id);
   function Side (Item : Model; Id : Pane_Id) return Dock_Side
     with Pre => Has_Pane (Item, Id);
   function Is_Collapsed (Item : Model; Id : Pane_Id) return Boolean
     with Pre => Has_Pane (Item, Id);

   procedure Float_Pane (Item : in out Model; Id : Pane_Id)
     with Pre => Has_Pane (Item, Id);
   --  Dock raises Structure_Error when another pane already occupies Side.
   procedure Dock_Pane
     (Item : in out Model; Id : Pane_Id; To_Side : Dock_Side)
     with Pre => Has_Pane (Item, Id);
   procedure Toggle_Collapsed (Item : in out Model; Id : Pane_Id)
     with Pre => Has_Pane (Item, Id);

   procedure Focus (Item : in out Model);
   procedure Blur (Item : in out Model);
   function Focused (Item : Model) return Boolean;
   procedure Focus_Pane (Item : in out Model; Id : Pane_Id)
     with Pre => Has_Pane (Item, Id);
   function Focused_Pane (Item : Model) return Pane_Id;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean);
   function Is_Enabled (Item : Model) return Boolean;

   --  Present returns one immutable frame shared by render and mouse routing.
   --  The center and every child region are exact clipped regions. Floating
   --  windows are composed in z-order after docks. Child body events are not
   --  consumed by Handle.
   function Present
     (Item       : Model;
      Children   : Surface_Array;
      Appearance : Dock_Workspaces.Appearance) return Presentation;
   function Present
     (Item       : Model;
      Children   : Surface_Array;
      Appearance : Dock_Workspaces.Appearance;
      Skin       : Flyology_TUI.Skins.Skin) return Presentation;
   function Present
     (Item     : Model;
      Children : Surface_Array;
      Skin     : Flyology_TUI.Skins.Skin) return Presentation;
   function Present
     (Item     : Model;
      Children : Surface_Array;
      Theme    : Flyology_TUI.Themes.Theme) return Presentation;

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface;
   function Center_Region
     (Item : Presentation) return Flyology_TUI.Geometry.Rectangle;
   function Has_Pane
     (Item : Presentation; Id : Pane_Id) return Boolean;
   function Pane_Region
     (Item : Presentation; Id : Pane_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Pane (Item, Id);
   function Header_Region
     (Item : Presentation; Id : Pane_Id)
      return Flyology_TUI.Geometry.Rectangle
     with Pre => Has_Pane (Item, Id);

   --  Keyboard input is accepted only while focused. Tab selects a pane,
   --  Enter collapses or expands a dock, F toggles floating/docked state, and
   --  Shift+arrow docks on a free edge. Floating panes retain the Windows
   --  Alt-arrow move and Control-arrow resize behavior.
   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   --  Coordinates are local to the workspace. Dock headers and rails own
   --  their chrome; child body clicks pass through. Floating windows acquire
   --  capture for move/resize. Releasing a header drag on a free workspace
   --  edge docks there. A stale presentation rejects new gestures, while an
   --  existing matching release always relinquishes capture.
   function Handle
     (Item   : in out Model;
      Layout : Presentation;
      Event  : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

private
   subtype Revision_Number is Interfaces.Unsigned_64;
   subtype Slot_Index is Positive range 1 .. Maximum_Panes;

   type Pane_State is record
      Used           : Boolean := False;
      Id             : Pane_Id := Pane_Id'First;
      Place          : Pane_Placement := Docked;
      Dock           : Dock_Side := Dock_Left;
      Dock_Extent    : Positive := 20;
      Minimum_Extent : Positive := 4;
      Collapsed      : Boolean := False;
      Floatable      : Boolean := True;
      Collapsible    : Boolean := True;
      Window         : Flyology_TUI.Components.Windows.Model :=
        Flyology_TUI.Components.Windows.Create
          (0, 0, 4, 3, Closable => False);
   end record;
   type Pane_State_Array is array (Slot_Index) of Pane_State;

   type Pane_Geometry is record
      Used   : Boolean := False;
      Id     : Pane_Id := Pane_Id'First;
      Region : Flyology_TUI.Geometry.Rectangle;
      Header : Flyology_TUI.Geometry.Rectangle;
      Content_Region : Flyology_TUI.Geometry.Rectangle;
      Float_Action : Flyology_TUI.Geometry.Rectangle;
      Toggle_Action : Flyology_TUI.Geometry.Rectangle;
   end record;
   type Pane_Geometry_Array is array (Slot_Index) of Pane_Geometry;

   type Presentation is record
      Image      : Flyology_TUI.Surfaces.Surface;
      Workspace  : Flyology_TUI.Geometry.Rectangle;
      Center     : Flyology_TUI.Geometry.Rectangle;
      Panes      : Pane_Geometry_Array;
      Version    : Revision_Number := 0;
   end record;

   type Capture_Kind is
     (No_Internal_Capture, Window_Interaction, Float_Action_Interaction,
      Toggle_Action_Interaction);

   type Model is tagged record
      Columns       : Natural := 0;
      Rows          : Natural := 0;
      Panes         : Pane_State_Array;
      Count         : Natural range 0 .. Maximum_Panes := 0;
      Enabled       : Boolean := True;
      Has_Focus     : Boolean := False;
      Active        : Slot_Index := Slot_Index'First;
      Top_Floating  : Slot_Index := Slot_Index'First;
      Capturing     : Boolean := False;
      Captured      : Slot_Index := Slot_Index'First;
      Capture_Mode  : Capture_Kind := No_Internal_Capture;
      Header_Drag   : Boolean := False;
      Has_Drop_Target : Boolean := False;
      Drop_Target_Side : Dock_Side := Dock_Left;
      Press_Region  : Flyology_TUI.Geometry.Rectangle;
      Capture_Revision : Revision_Number := 0;
      Revision      : Revision_Number := 0;
   end record;
end Flyology_TUI.Components.Dock_Workspaces;
