with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Chats is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function Symbol (Code : Natural) return Wide_Wide_String is
     (Wide_Wide_String'(1 => Wide_Wide_Character'Val (Code)));

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Transcript => Theme.Primary,
      Header     => Theme.Muted,
      User_Bubble => Theme.Input,
      Assistant_Bubble => Theme.Primary,
      System_Bubble => Theme.Muted,
      Tool_Bubble => Theme.Success,
      Notice_Bubble => Theme.Error,
      User       => Theme.Input,
      Assistant  => Theme.Primary,
      System     => Theme.Muted,
      Tool       => Theme.Success,
      Notice     => Theme.Error,
      Pending    => Theme.Muted,
      Streaming  => Theme.Focused,
      Failed     => Theme.Error,
      Selected   => Theme.Selected,
      Focused    => Theme.Focused,
      Footer     => Theme.Muted,
      Composer   => Theme.Input);

   function Find
     (Values : Message_Vectors.Vector;
      Id     : Message_Id) return Natural
   is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Values.Element (Index).Id = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Find;

   function Find
     (Values : Id_Vectors.Vector;
      Id     : Message_Id) return Natural
   is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Values.Element (Index) = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Find;

   function Find
     (Values : Measurement_Array;
      Id     : Message_Id) return Natural
   is
   begin
      for Index in Values'Range loop
         if Values (Index).Id = Id then
            return Natural (Index);
         end if;
      end loop;
      return 0;
   end Find;

   function Safe_Add (Left, Right : Natural) return Natural is
   begin
      if Right > Natural'Last - Left then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      return Left + Right;
   end Safe_Add;

   function Block_Height
     (Body_Height, Action_Height : Natural) return Natural is
     (Safe_Add (1, Safe_Add (Body_Height, Action_Height)));

   function Content_Height_Of
     (Item : Model; Options : Layout_Options) return Natural is
      Result : Natural := 0;
   begin
      if Item.Messages.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Item.Messages.Length) - 1 loop
         if Index > 0 then
            Result := Safe_Add (Result, Options.Message_Gap);
         end if;
         Result := Safe_Add
           (Result,
            Block_Height
              (Item.Body_Heights.Element (Index),
               Item.Action_Heights.Element (Index)));
      end loop;
      return Result;
   end Content_Height_Of;

   function Content_Height_Of (Item : Model) return Natural is
     (Content_Height_Of (Item, Item.Options));

   function Maximum_First (Item : Model) return Natural is
      Total : constant Natural := Content_Height_Of (Item);
   begin
      if Total > Item.Rows then
         return Total - Item.Rows;
      end if;
      return 0;
   end Maximum_First;

   procedure Normalize_Viewport (Item : in out Model) is
      Last_First : constant Natural := Maximum_First (Item);
   begin
      if Item.Follow_Tail then
         Item.First_Cell := Last_First;
         Item.Unread := 0;
      elsif Item.First_Cell > Last_First then
         Item.First_Cell := Last_First;
      end if;
   end Normalize_Viewport;

   procedure Validate (Messages : Message_Array) is
   begin
      if Messages'Length > Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      for Left in Messages'Range loop
         for Right in Messages'Range loop
            if Right > Left and then Messages (Left).Id = Messages (Right).Id
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;
   end Validate;

   procedure Set_Messages
     (Item     : in out Model;
      Messages : Message_Array)
   is
      New_Messages : Message_Vectors.Vector;
      New_Bodies   : Natural_Vectors.Vector;
      New_Actions  : Natural_Vectors.Vector;
      New_Focused  : Natural := 0;
      New_Selected : Natural := 0;
      Added        : Natural := 0;
      Old_Index    : Natural;
      New_Total    : Natural := 0;
   begin
      Validate (Messages);
      for Value of Messages loop
         Old_Index := Find (Item.Messages, Value.Id);
         New_Messages.Append (Value);
         if Old_Index = 0 then
            New_Bodies.Append (1);
            New_Actions.Append (0);
            Added := Added + 1;
         else
            New_Bodies.Append (Item.Body_Heights.Element (Old_Index - 1));
            New_Actions.Append (Item.Action_Heights.Element (Old_Index - 1));
            if Item.Focused = Old_Index then
               New_Focused := Natural (New_Messages.Length);
            end if;
            if Item.Selected = Old_Index then
               New_Selected := Natural (New_Messages.Length);
            end if;
         end if;
      end loop;

      if New_Focused = 0 and then not New_Messages.Is_Empty then
         New_Focused := 1;
      end if;

      if not New_Messages.Is_Empty then
         for Index in 0 .. Natural (New_Messages.Length) - 1 loop
            if Index > 0 then
               New_Total := Safe_Add
                 (New_Total, Item.Options.Message_Gap);
            end if;
            New_Total := Safe_Add
              (New_Total,
               Block_Height
                 (New_Bodies.Element (Index),
                  New_Actions.Element (Index)));
         end loop;
      end if;

      Item.Messages := New_Messages;
      Item.Body_Heights := New_Bodies;
      Item.Action_Heights := New_Actions;
      Item.Focused := New_Focused;
      Item.Selected := New_Selected;
      if not Item.Follow_Tail and then Added > 0 then
         declare
            Existing : constant Natural := Natural'Min (Item.Unread, Capacity);
         begin
            if Added >= Capacity - Existing then
               Item.Unread := Capacity;
            else
               Item.Unread := Existing + Added;
            end if;
         end;
      end if;
      Normalize_Viewport (Item);
   end Set_Messages;

   function Create
     (Messages      : Message_Array;
      Viewport_Rows : Natural := 12) return Model
   is
      Result : Model;
   begin
      Result.Rows := Viewport_Rows;
      Set_Messages (Result, Messages);
      return Result;
   end Create;

   procedure Set_Layout
     (Item : in out Model; Options : Layout_Options)
   is
      Validated_Height : constant Natural := Content_Height_Of (Item, Options);
      pragma Unreferenced (Validated_Height);
   begin
      Item.Options := Options;
      Normalize_Viewport (Item);
   end Set_Layout;

   function Layout (Item : Model) return Layout_Options is (Item.Options);

   procedure Reconcile_Measurements
     (Item         : in out Model;
      Measurements : Measurement_Array)
   is
      New_Bodies  : Natural_Vectors.Vector;
      New_Actions : Natural_Vectors.Vector;
      Total       : Natural := 0;
      Position    : Natural;
   begin
      if Measurements'Length /= Natural (Item.Messages.Length) then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      for Left in Measurements'Range loop
         if Find (Item.Messages, Measurements (Left).Id) = 0 then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
         for Right in Measurements'Range loop
            if Right > Left
              and then Measurements (Left).Id = Measurements (Right).Id
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;

      if not Item.Messages.Is_Empty then
         for Index in 0 .. Natural (Item.Messages.Length) - 1 loop
            Position := Find (Measurements, Item.Messages.Element (Index).Id);
            if Position = 0 then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
            New_Bodies.Append
              (Measurements (Positive (Position)).Body_Height);
            New_Actions.Append
              (Measurements (Positive (Position)).Action_Height);
            if Index > 0 then
               Total := Safe_Add (Total, Item.Options.Message_Gap);
            end if;
            Total := Safe_Add
              (Total,
               Block_Height
                 (Measurements (Positive (Position)).Body_Height,
                  Measurements (Positive (Position)).Action_Height));
         end loop;
      end if;

      Item.Body_Heights := New_Bodies;
      Item.Action_Heights := New_Actions;
      Normalize_Viewport (Item);
   end Reconcile_Measurements;

   procedure Set_Viewport_Rows (Item : in out Model; Rows : Natural) is
   begin
      Item.Rows := Rows;
      Normalize_Viewport (Item);
   end Set_Viewport_Rows;

   function Viewport_Rows (Item : Model) return Natural is (Item.Rows);
   function Content_Height (Item : Model) return Natural is
     (Content_Height_Of (Item));
   function First_Visible_Cell (Item : Model) return Natural is
     (Item.First_Cell);
   function Length (Item : Model) return Natural is
     (Natural (Item.Messages.Length));
   function Is_Empty (Item : Model) return Boolean is
     (Item.Messages.Is_Empty);
   function Contains (Item : Model; Id : Message_Id) return Boolean is
     (Find (Item.Messages, Id) > 0);
   function Message_At (Item : Model; Position : Positive) return Message is
     (Item.Messages.Element (Position - 1));
   function Has_Focused_Message (Item : Model) return Boolean is
     (Item.Focused > 0);
   function Focused_Id (Item : Model) return Message_Id is
     (Item.Messages.Element (Item.Focused - 1).Id);
   function Has_Selection (Item : Model) return Boolean is
     (Item.Selected > 0);
   function Selected_Id (Item : Model) return Message_Id is
     (Item.Messages.Element (Item.Selected - 1).Id);

   procedure Select_Id (Item : in out Model; Id : Message_Id) is
      Index : constant Natural := Find (Item.Messages, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Selected := Index;
      Item.Focused := Index;
   end Select_Id;

   procedure Clear_Selection (Item : in out Model) is
   begin
      Item.Selected := 0;
   end Clear_Selection;

   procedure Set_Follow_Tail
     (Item    : in out Model;
      Enabled : Boolean := True) is
   begin
      Item.Follow_Tail := Enabled;
      Normalize_Viewport (Item);
   end Set_Follow_Tail;

   function Follows_Tail (Item : Model) return Boolean is (Item.Follow_Tail);
   function Unread_Count (Item : Model) return Natural is (Item.Unread);

   procedure Mark_All_Seen (Item : in out Model) is
   begin
      Item.Unread := 0;
   end Mark_All_Seen;

   procedure Scroll_Cells
     (Item    : in out Model;
      Amount  : Integer;
      Changed : out Boolean)
   is
      Old_First  : constant Natural := Item.First_Cell;
      Old_Follow : constant Boolean := Item.Follow_Tail;
      Old_Unread : constant Natural := Item.Unread;
      Limit      : constant Natural := Maximum_First (Item);
   begin
      if Amount < 0 then
         Item.Follow_Tail := False;
         if Amount = Integer'First
           or else Natural (-Amount) >= Item.First_Cell
         then
            Item.First_Cell := 0;
         else
            Item.First_Cell := Item.First_Cell - Natural (-Amount);
         end if;
      elsif Amount > 0 then
         if Natural (Amount) >= Limit - Item.First_Cell then
            Item.First_Cell := Limit;
            Item.Follow_Tail := True;
            Item.Unread := 0;
         else
            Item.First_Cell := Item.First_Cell + Natural (Amount);
            Item.Follow_Tail := False;
         end if;
      end if;
      Changed := Item.First_Cell /= Old_First
        or else Item.Follow_Tail /= Old_Follow
        or else Item.Unread /= Old_Unread;
   end Scroll_Cells;

   function Signed_Difference (Left, Right : Natural) return Integer is
   begin
      if Left >= Right then
         if Left - Right > Natural (Integer'Last) then
            return Integer'Last;
         end if;
         return Integer (Left - Right);
      elsif Right - Left > Natural (Integer'Last) then
         return Integer'First;
      else
         return -Integer (Right - Left);
      end if;
   end Signed_Difference;

   function Clip_To_Viewport
     (Segment_Start : Natural;
      Segment_End   : Natural;
      View_Start    : Natural;
      View_End      : Natural;
      Width         : Natural) return Flyology_TUI.Geometry.Rectangle
   is
      Visible_Start : Natural;
      Visible_End   : Natural;
   begin
      if Segment_Start >= View_End or else Segment_End <= View_Start then
         return (X => 0, Y => 0, Width => Width, Height => 0);
      end if;
      Visible_Start := Natural'Max (Segment_Start, View_Start);
      Visible_End := Natural'Min (Segment_End, View_End);
      return
        (X      => 0,
         Y      => Integer (Visible_Start - View_Start),
         Width  => Width,
         Height => Visible_End - Visible_Start);
   end Clip_To_Viewport;

   function Plan
     (Item            : Model;
      Width           : Natural;
      Footer_Height   : Natural := 0;
      Composer_Height : Natural := 0) return Layout_Plan
   is
      Result       : Layout_Plan;
      Frame_Height : Natural;
      Total        : constant Natural := Content_Height_Of (Item);
      View_End     : Natural;
      Block_Start  : Natural := 0;
   begin
      Frame_Height := Safe_Add
        (Item.Rows, Safe_Add (Footer_Height, Composer_Height));
      if Width /= 0 and then Frame_Height > Natural'Last / Width
      then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;

      Result.Frame_Width := Width;
      Result.Frame_Height := Frame_Height;
      Result.Transcript_Value :=
        (X => 0, Y => 0, Width => Width, Height => Item.Rows);
      Result.Footer_Value :=
        (X      => 0,
         Y      => Integer (Item.Rows),
         Width  => Width,
         Height => Footer_Height);
      Result.Composer_Value :=
        (X      => 0,
         Y      => Integer (Safe_Add (Item.Rows, Footer_Height)),
         Width  => Width,
         Height => Composer_Height);

      if Item.Rows >= Total - Item.First_Cell then
         View_End := Total;
      else
         View_End := Item.First_Cell + Item.Rows;
      end if;

      if not Item.Messages.Is_Empty and then Item.Rows > 0 then
         for Index in 0 .. Natural (Item.Messages.Length) - 1 loop
            declare
               Body_Height : constant Natural :=
                 Item.Body_Heights.Element (Index);
               Action_Height : constant Natural :=
                 Item.Action_Heights.Element (Index);
               Body_Start : constant Natural := Safe_Add (Block_Start, 1);
               Action_Start : constant Natural :=
                 Safe_Add (Body_Start, Body_Height);
               Block_End : constant Natural :=
                 Safe_Add (Action_Start, Action_Height);
            begin
               if Block_Start < View_End
                 and then Block_End > Item.First_Cell
               then
                  Result.Ids.Append (Item.Messages.Element (Index).Id);
                  Result.Header_Regions.Append
                    (Clip_To_Viewport
                       (Block_Start,
                        Safe_Add (Block_Start, 1),
                        Item.First_Cell,
                        View_End,
                        Width));
                  Result.Body_Origins.Append
                    (Signed_Difference (Body_Start, Item.First_Cell));
                  Result.Action_Origins.Append
                    (Signed_Difference (Action_Start, Item.First_Cell));
                  Result.Body_Regions.Append
                    (Clip_To_Viewport
                       (Body_Start,
                        Action_Start,
                        Item.First_Cell,
                        View_End,
                        Width));
                  Result.Action_Regions.Append
                    (Clip_To_Viewport
                       (Action_Start,
                        Block_End,
                        Item.First_Cell,
                        View_End,
                        Width));
                  Result.Bubble_Regions.Append
                    (Flyology_TUI.Geometry.Rectangle'
                       (X      => 0,
                        Y      => Signed_Difference
                          (Block_Start, Item.First_Cell),
                        Width  => Width,
                        Height => Block_End - Block_Start));
               end if;
               Block_Start := Block_End;
               if Index < Natural (Item.Messages.Length) - 1 then
                  Block_Start := Safe_Add
                    (Block_Start, Item.Options.Message_Gap);
               end if;
            end;
         end loop;
      end if;
      return Result;
   end Plan;

   function Width (Item : Layout_Plan) return Natural is (Item.Frame_Width);
   function Height (Item : Layout_Plan) return Natural is (Item.Frame_Height);
   function Transcript_Region
     (Item : Layout_Plan) return Flyology_TUI.Geometry.Rectangle is
     (Item.Transcript_Value);
   function Has_Footer (Item : Layout_Plan) return Boolean is
     (Item.Footer_Value.Height > 0);
   function Footer_Region
     (Item : Layout_Plan) return Flyology_TUI.Geometry.Rectangle is
     (Item.Footer_Value);
   function Has_Composer (Item : Layout_Plan) return Boolean is
     (Item.Composer_Value.Height > 0);
   function Composer_Region
     (Item : Layout_Plan) return Flyology_TUI.Geometry.Rectangle is
     (Item.Composer_Value);
   function Required_Body_Count (Item : Layout_Plan) return Natural is
     (Natural (Item.Ids.Length));
   function Required_Body_Id
     (Item : Layout_Plan; Position : Positive) return Message_Id is
     (Item.Ids.Element (Position - 1));
   function Requires_Body
     (Item : Layout_Plan; Id : Message_Id) return Boolean is
     (Find (Item.Ids, Id) > 0);

   function Body_Index
     (Bodies : Body_Array;
      Id     : Message_Id) return Natural
   is
   begin
      for Index in Bodies'Range loop
         if Bodies (Index).Id = Id then
            return Natural (Index);
         end if;
      end loop;
      return 0;
   end Body_Index;

   procedure Validate_Bodies
     (Item   : Model;
      Bodies : Body_Array;
      Layout : Layout_Plan)
   is
   begin
      if Bodies'Length /= Required_Body_Count (Layout) then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      for Left in Bodies'Range loop
         if not Requires_Body (Layout, Bodies (Left).Id) then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
         for Right in Bodies'Range loop
            if Right > Left and then Bodies (Left).Id = Bodies (Right).Id then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
         declare
            Message_Position : constant Natural :=
              Find (Item.Messages, Bodies (Left).Id);
         begin
            if Message_Position = 0
              or else Bodies (Left).Content.Height /=
                Item.Body_Heights.Element (Message_Position - 1)
              or else Bodies (Left).Actions.Height /=
                Item.Action_Heights.Element (Message_Position - 1)
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end;
      end loop;
   end Validate_Bodies;

   function Role_Style
     (Kind : Message_Role;
      Look : Appearance) return Flyology_TUI.Styles.Style is
     (case Kind is
         when User      => Look.User,
         when Assistant => Look.Assistant,
         when System    => Look.System,
         when Tool      => Look.Tool,
         when Notice    => Look.Notice);

   function Role_Label (Kind : Message_Role) return Wide_Wide_String is
     (case Kind is
         when User      => "user",
         when Assistant => "assistant",
         when System    => "system",
         when Tool      => "tool",
         when Notice    => "notice");

   function Delivery_Label
     (State : Delivery_State) return Wide_Wide_String is
     (case State is
         when Pending   => "pending",
         when Streaming => "streaming",
         when Delivered => "",
         when Failed    => "failed",
         when Cancelled => "cancelled");

   function Header_Style
     (Value     : Message;
      Selected  : Boolean;
      Focused   : Boolean;
      Has_Focus : Boolean;
      Look      : Appearance) return Flyology_TUI.Styles.Style is
   begin
      if Selected then
         return Look.Selected;
      elsif Focused and then Has_Focus then
         return Look.Focused;
      end if;
      case Value.Delivery is
         when Failed => return Look.Failed;
         when Streaming => return Look.Streaming;
         when Pending | Cancelled => return Look.Pending;
         when Delivered => return Role_Style (Value.Role, Look);
      end case;
   end Header_Style;

   function Bubble_Style
     (Value     : Message;
      Selected  : Boolean;
      Focused   : Boolean;
      Has_Focus : Boolean;
      Look      : Appearance) return Flyology_TUI.Styles.Style is
   begin
      if Selected then
         return Look.Selected;
      elsif Focused and then Has_Focus then
         return Look.Focused;
      end if;
      return
        (case Value.Role is
            when User      => Look.User_Bubble,
            when Assistant => Look.Assistant_Bubble,
            when System    => Look.System_Bubble,
            when Tool      => Look.Tool_Bubble,
            when Notice    => Look.Notice_Bubble);
   end Bubble_Style;

   function Header_Text
     (Value : Message) return Wide_Wide_String
   is
      State : constant Wide_Wide_String := Delivery_Label (Value.Delivery);
   begin
      return Symbol (16#258D#) & " " & Author_Label (Value.Author)
        & " " & Symbol (16#00B7#) & " " & Role_Label (Value.Role)
        & (if State'Length = 0
           then ""
           else " " & Symbol (16#00B7#) & " " & State);
   end Header_Text;

   function Message_Width_Limit
     (Width : Natural; Options : Layout_Options) return Natural
   is
      Percent_Width : Natural;
   begin
      if Width = 0 then
         return 0;
      end if;
      Percent_Width :=
        (Width / 100) * Options.Maximum_Percentage
        + (Width mod 100) * Options.Maximum_Percentage / 100;
      return Natural'Max
        (1,
         Natural'Min
           (Width,
            Natural'Min (Options.Maximum_Message_Width, Percent_Width)));
   end Message_Width_Limit;

   function Body_Width_Limit
     (Item : Model; Frame_Width : Natural) return Natural
   is
   begin
      if Item.Options.Mode = Dense_Transcript then
         return Frame_Width;
      end if;
      declare
         Limit : constant Natural :=
           Message_Width_Limit (Frame_Width, Item.Options);
         Padding : constant Natural :=
           Natural'Min (Item.Options.Horizontal_Padding, Limit / 2);
      begin
         return Limit - 2 * Padding;
      end;
   end Body_Width_Limit;

   function Present_Core
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Footer    : Flyology_TUI.Surfaces.Surface;
      Composer  : Flyology_TUI.Surfaces.Surface;
      Look      : Appearance;
      Has_Focus : Boolean) return Presentation
   is
      Result : Presentation;
   begin
      Result.Layout_Value := Plan
        (Item, Width, Footer.Height, Composer.Height);
      Validate_Bodies (Item, Bodies, Result.Layout_Value);
      Result.Frame_Value := Flyology_TUI.Surfaces.Create
        (Width, Result.Layout_Value.Frame_Height, Look.Transcript);

      for Visible in 1 .. Required_Body_Count (Result.Layout_Value) loop
         declare
            Id : constant Message_Id :=
              Required_Body_Id (Result.Layout_Value, Visible);
            Index : constant Natural := Find (Item.Messages, Id);
            Body_Position : constant Natural := Body_Index (Bodies, Id);
            Value : constant Message := Item.Messages.Element (Index - 1);
            Chosen : constant Flyology_TUI.Styles.Style := Header_Style
              (Value,
               Selected  => Item.Selected = Index,
               Focused   => Item.Focused = Index,
               Has_Focus => Has_Focus,
               Look      => Look);
            Label : constant Wide_Wide_String := Header_Text (Value);
            Limit : constant Natural :=
              Message_Width_Limit (Width, Item.Options);
            Desired : constant Natural := Natural'Max
              (Flyology_TUI.Glyphs.Width_Of (Label),
               Natural'Max
                 (Bodies (Positive (Body_Position)).Content.Width,
                  Bodies (Positive (Body_Position)).Actions.Width));
            Padded : constant Natural :=
              (if Item.Options.Horizontal_Padding
                    > Natural'Last / 2
               or else Desired
                 > Natural'Last - 2 * Item.Options.Horizontal_Padding
               then Natural'Last
               else Desired + 2 * Item.Options.Horizontal_Padding);
            Bubble_Width : constant Natural :=
              (if Item.Options.Mode = Dense_Transcript
               then Width else Natural'Min (Limit, Padded));
            Inner_X : constant Natural :=
              (if Item.Options.Mode = Dense_Transcript
               then 0
               else Natural'Min
                 (Item.Options.Horizontal_Padding, Bubble_Width / 2));
            Inner_Width : constant Natural :=
              Bubble_Width - 2 * Inner_X;
            Bubble_X : constant Natural :=
              (if Value.Role = User and then Width > Bubble_Width
               then Width - Bubble_Width else 0);
            Bubble_Y : constant Integer :=
              Result.Layout_Value.Bubble_Regions.Element (Visible - 1).Y;
            Bubble_Height : constant Natural := Block_Height
              (Item.Body_Heights.Element (Index - 1),
               Item.Action_Heights.Element (Index - 1));
            Bubble : Flyology_TUI.Surfaces.Surface :=
              Flyology_TUI.Surfaces.Create
                (Bubble_Width, Bubble_Height,
                 Bubble_Style
                   (Value, Item.Selected = Index, Item.Focused = Index,
                    Has_Focus, Look));
            Header : Flyology_TUI.Surfaces.Surface :=
              Flyology_TUI.Surfaces.Create
                (Inner_Width, 1, Look.Header);
            Body_Region : Flyology_TUI.Geometry.Rectangle :=
              Result.Layout_Value.Body_Regions.Element (Visible - 1);
            Action_Region : Flyology_TUI.Geometry.Rectangle :=
              Result.Layout_Value.Action_Regions.Element (Visible - 1);
            Header_Region : Flyology_TUI.Geometry.Rectangle :=
              Result.Layout_Value.Header_Regions.Element (Visible - 1);
            Visible_Bubble_Y : constant Integer := Integer'Max (0, Bubble_Y);
            Visible_Bubble_End : constant Integer := Integer'Min
              (Integer (Item.Rows), Bubble_Y + Integer (Bubble_Height));
         begin
            if Item.Options.Mode = Dense_Transcript then
               Header := Flyology_TUI.Surfaces.Create
                 (Width, 1, Look.Header);
               Header.Write (0, 0, Label, Chosen);
               Result.Frame_Value.Overlay_Clipped
                 (Header, 0, Bubble_Y);
               Result.Frame_Value.Overlay_Clipped
                 (Bodies (Positive (Body_Position)).Content,
                  0,
                  Result.Layout_Value.Body_Origins.Element (Visible - 1));
               Result.Frame_Value.Overlay_Clipped
                 (Bodies (Positive (Body_Position)).Actions,
                  0,
                  Result.Layout_Value.Action_Origins.Element (Visible - 1));
               Result.Layout_Value.Bubble_Regions.Replace_Element
                 (Visible - 1,
                  (X => 0, Y => Visible_Bubble_Y, Width => Width,
                   Height =>
                     (if Visible_Bubble_End > Visible_Bubble_Y
                      then Natural (Visible_Bubble_End - Visible_Bubble_Y)
                      else 0)));
            else
               Header.Write
                 (0, 0, Label, Chosen);
               Bubble.Overlay_Clipped (Header, Integer (Inner_X), 0);
               Bubble.Overlay_Clipped
                 (Bodies (Positive (Body_Position)).Content,
                  Integer (Inner_X), 1, Transparent_Spaces => True);
               Bubble.Overlay_Clipped
                 (Bodies (Positive (Body_Position)).Actions,
                  Integer (Inner_X),
                  Integer (1 + Item.Body_Heights.Element (Index - 1)),
                  Transparent_Spaces => True);
               Result.Frame_Value.Overlay_Clipped
                 (Bubble, Integer (Bubble_X), Bubble_Y);
               Header_Region.X := Integer (Bubble_X);
               Header_Region.Width := Bubble_Width;
               Result.Layout_Value.Header_Regions.Replace_Element
                 (Visible - 1, Header_Region);
               Body_Region.X := Integer (Bubble_X + Inner_X);
               Body_Region.Width := Natural'Min
                 (Inner_Width,
                  Bodies (Positive (Body_Position)).Content.Width);
               Result.Layout_Value.Body_Regions.Replace_Element
                 (Visible - 1, Body_Region);
               Action_Region.X := Integer (Bubble_X + Inner_X);
               Action_Region.Width := Natural'Min
                 (Inner_Width,
                  Bodies (Positive (Body_Position)).Actions.Width);
               Result.Layout_Value.Action_Regions.Replace_Element
                 (Visible - 1, Action_Region);
               Result.Layout_Value.Bubble_Regions.Replace_Element
                 (Visible - 1,
                  (X => Integer (Bubble_X), Y => Visible_Bubble_Y,
                   Width => Bubble_Width,
                   Height =>
                     (if Visible_Bubble_End > Visible_Bubble_Y
                      then Natural (Visible_Bubble_End - Visible_Bubble_Y)
                      else 0)));
            end if;
         end;
      end loop;

      if Footer.Height > 0 then
         declare
            Canvas : Flyology_TUI.Surfaces.Surface :=
              Flyology_TUI.Surfaces.Create
                (Width, Footer.Height, Look.Footer);
         begin
            Canvas.Overlay_Clipped (Footer, 0, 0);
            Result.Frame_Value.Overlay_Clipped
              (Canvas, 0, Result.Layout_Value.Footer_Value.Y);
         end;
      end if;
      if Composer.Height > 0 then
         declare
            Canvas : Flyology_TUI.Surfaces.Surface :=
              Flyology_TUI.Surfaces.Create
                (Width, Composer.Height, Look.Composer);
         begin
            Canvas.Overlay_Clipped (Composer, 0, 0);
            Result.Frame_Value.Overlay_Clipped
              (Canvas, 0, Result.Layout_Value.Composer_Value.Y);
         end;
      end if;
      return Result;
   end Present_Core;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation
   is
      Empty : constant Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (0, 0);
   begin
      return Present_Core
        (Item, Bodies, Width, Empty, Empty, Look, Has_Focus);
   end Present;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Footer    : Flyology_TUI.Surfaces.Surface;
      Composer  : Flyology_TUI.Surfaces.Surface;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation is
     (Present_Core
        (Item, Bodies, Width, Footer, Composer, Look, Has_Focus));

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation is
     (Present (Item, Bodies, Width, From_Theme (Theme), Has_Focus));

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Footer    : Flyology_TUI.Surfaces.Surface;
      Composer  : Flyology_TUI.Surfaces.Surface;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation is
     (Present
        (Item, Bodies, Width, Footer, Composer,
         From_Theme (Theme), Has_Focus));

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface is
     (Item.Frame_Value);
   function Layout (Item : Presentation) return Layout_Plan is
     (Item.Layout_Value);

   function Presentation_Index
     (Item : Presentation;
      Id   : Message_Id) return Natural is
     (Find (Item.Layout_Value.Ids, Id));

   function Has_Message
     (Item : Presentation; Id : Message_Id) return Boolean is
     (Presentation_Index (Item, Id) > 0);
   function Bubble_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle is
     (Item.Layout_Value.Bubble_Regions.Element
        (Presentation_Index (Item, Id) - 1));
   function Header_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle is
     (Item.Layout_Value.Header_Regions.Element
        (Presentation_Index (Item, Id) - 1));
   function Body_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle is
     (Item.Layout_Value.Body_Regions.Element
        (Presentation_Index (Item, Id) - 1));
   function Has_Action_Region
     (Item : Presentation; Id : Message_Id) return Boolean
   is
      Index : constant Natural := Presentation_Index (Item, Id);
   begin
      return Index > 0
        and then
          Item.Layout_Value.Action_Regions.Element (Index - 1).Height > 0;
   end Has_Action_Region;
   function Action_Region
     (Item : Presentation; Id : Message_Id)
      return Flyology_TUI.Geometry.Rectangle is
     (Item.Layout_Value.Action_Regions.Element
        (Presentation_Index (Item, Id) - 1));

   function Block_Start_At
     (Item : Model;
      Position : Positive) return Natural
   is
      Result : Natural := 0;
   begin
      if Position > 1 then
         for Index in 0 .. Position - 2 loop
            Result := Safe_Add
              (Result,
               Block_Height
                 (Item.Body_Heights.Element (Index),
                  Item.Action_Heights.Element (Index)));
            Result := Safe_Add (Result, Item.Options.Message_Gap);
         end loop;
      end if;
      return Result;
   end Block_Start_At;

   procedure Ensure_Focused_Visible (Item : in out Model) is
      Start : Natural;
      Stop  : Natural;
      End_Of_View : Natural;
      Limit : constant Natural := Maximum_First (Item);
   begin
      if Item.Focused = 0 then
         return;
      end if;
      Start := Block_Start_At (Item, Positive (Item.Focused));
      Stop := Safe_Add
        (Start,
         Block_Height
           (Item.Body_Heights.Element (Item.Focused - 1),
            Item.Action_Heights.Element (Item.Focused - 1)));
      if Item.Rows >= Content_Height_Of (Item) - Item.First_Cell then
         End_Of_View := Content_Height_Of (Item);
      else
         End_Of_View := Item.First_Cell + Item.Rows;
      end if;
      if Start < Item.First_Cell then
         Item.First_Cell := Start;
         Item.Follow_Tail := False;
      elsif Stop > End_Of_View then
         if Stop > Item.Rows then
            Item.First_Cell := Natural'Min (Stop - Item.Rows, Limit);
         else
            Item.First_Cell := 0;
         end if;
         Item.Follow_Tail := Item.First_Cell = Limit;
         if Item.Follow_Tail then
            Item.Unread := 0;
         end if;
      end if;
   end Ensure_Focused_Visible;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Old_Focused : constant Natural := Item.Focused;
      Old_Selected : constant Natural := Item.Selected;
      Old_First : constant Natural := Item.First_Cell;
      Old_Follow : constant Boolean := Item.Follow_Tail;
      Old_Unread : constant Natural := Item.Unread;
      Changed : Boolean := False;
   begin
      if Event.Kind /= Flyology_TUI.Events.Key_Press
        or else Item.Messages.Is_Empty
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            if Item.Focused > 1 then
               Item.Focused := Item.Focused - 1;
            end if;
            Ensure_Focused_Visible (Item);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            if Item.Focused < Natural (Item.Messages.Length) then
               Item.Focused := Item.Focused + 1;
            end if;
            Ensure_Focused_Visible (Item);
         when Flyology_TUI.Events.Home_Key =>
            Item.Focused := 1;
            Ensure_Focused_Visible (Item);
         when Flyology_TUI.Events.End_Key =>
            Item.Focused := Natural (Item.Messages.Length);
            Set_Follow_Tail (Item, True);
         when Flyology_TUI.Events.Page_Up_Key =>
            Scroll_Cells
              (Item,
               -Integer (Item.Rows),
               Changed);
         when Flyology_TUI.Events.Page_Down_Key =>
            Scroll_Cells
              (Item,
               Integer (Item.Rows),
               Changed);
         when Flyology_TUI.Events.Enter_Key =>
            Item.Selected := Item.Focused;
            return
              (Handled   => True,
               Activated => True,
               Changed   => Item.Selected /= Old_Selected,
               others    => <>);
         when Flyology_TUI.Events.Escape_Key =>
            Item.Selected := 0;
            return
              (Handled => True,
               Changed => Old_Selected /= 0,
               others  => <>);
         when others =>
            return Flyology_TUI.Components.Interactions.Ignored;
      end case;
      return
        (Handled => True,
         Changed =>
           Changed
           or else Item.Focused /= Old_Focused
           or else Item.First_Cell /= Old_First
           or else Item.Follow_Tail /= Old_Follow
           or else Item.Unread /= Old_Unread,
         others  => <>);
   end Handle;

   function Header_Hit
     (Layout : Presentation;
      Event  : Flyology_TUI.Mouse.Local_Event) return Natural
   is
   begin
      if Layout.Layout_Value.Header_Regions.Is_Empty then
         return 0;
      end if;
      for Index in 0 ..
        Natural (Layout.Layout_Value.Header_Regions.Length) - 1
      loop
         if Flyology_TUI.Geometry.Contains
           (Layout.Layout_Value.Header_Regions.Element (Index),
            Event.X, Event.Y)
         then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Header_Hit;

   function Child_Hit
     (Layout : Presentation;
      Event  : Flyology_TUI.Mouse.Local_Event) return Boolean
   is
   begin
      if Layout.Layout_Value.Ids.Is_Empty then
         return False;
      end if;
      for Index in 0 .. Natural (Layout.Layout_Value.Ids.Length) - 1 loop
         if Flyology_TUI.Geometry.Contains
           (Layout.Layout_Value.Body_Regions.Element (Index),
            Event.X, Event.Y)
           or else Flyology_TUI.Geometry.Contains
             (Layout.Layout_Value.Action_Regions.Element (Index),
              Event.X, Event.Y)
         then
            return True;
         end if;
      end loop;
      return False;
   end Child_Hit;

   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : Boolean := False;
      Hit     : Natural;
      Index   : Natural;
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Event.Wheel_Y /= 0
        and then Child_Hit (Layout, Event)
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Wheel
        and then Event.Wheel_Y /= 0
        and then Flyology_TUI.Geometry.Contains
          (Layout.Layout_Value.Transcript_Value, Event.X, Event.Y)
      then
         if Event.Wheel_Y > 0 then
            Scroll_Cells
              (Item,
               (if Event.Wheel_Y = Integer'Last
                then Integer'First else -Event.Wheel_Y),
               Changed);
         else
            Scroll_Cells
              (Item,
               (if Event.Wheel_Y = Integer'First
                then Integer'Last else -Event.Wheel_Y),
               Changed);
         end if;
         return
           (Handled => True,
            Focus_Requested => True,
            Changed => Changed,
            others => <>);
      elsif Event.Action /= Flyology_TUI.Events.Mouse_Click
        or else Event.Button /= Flyology_TUI.Events.Left_Button
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;

      Hit := Header_Hit (Layout, Event);
      if Hit = 0 then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      Index := Find
        (Item.Messages, Layout.Layout_Value.Ids.Element (Hit - 1));
      if Index = 0 then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      Changed := Item.Focused /= Index or else Item.Selected /= Index;
      Item.Focused := Index;
      Item.Selected := Index;
      return
        (Handled => True,
         Focus_Requested => True,
         Activated => True,
         Changed => Changed,
         others => <>);
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   procedure Update
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event, Layout);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

end Flyology_TUI.Components.Chats;
