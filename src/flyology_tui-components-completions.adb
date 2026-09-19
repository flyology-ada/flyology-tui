with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Completions is
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;

   --  Structural gutter between tabulated columns. Two cells is the
   --  separation a shell listing uses; it is presentation chrome rather
   --  than a caller policy, so it stays private to this body.
   Column_Gap : constant := 2;

   --  Persistent non-color cue for the selected candidate. Both
   --  presentations reserve the same two cells so the selection survives a
   --  monochrome profile and an all-default Appearance.
   Selected_Mark : constant Wide_Wide_String := "> ";
   Unselected_Mark : constant Wide_Wide_String := "  ";
   Mark_Cells : constant := 2;

   function Candidate_Of
     (Insert  : Wide_Wide_String;
      Display : Wide_Wide_String := "";
      Detail  : Wide_Wide_String := "";
      Kind    : Category := Category'First) return Candidate
   is (Insert  => Text.To_Unbounded_Wide_Wide_String (Insert),
       Display =>
         Text.To_Unbounded_Wide_Wide_String
           ((if Display'Length = 0 then Insert else Display)),
       Detail  => Text.To_Unbounded_Wide_Wide_String (Detail),
       Kind    => Kind);

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is (Normal     => Theme.Primary,
       Selected   => Theme.Selected,
       Detail     => Theme.Muted,
       Counter    => Theme.Muted,
       Categories => (others => Flyology_TUI.Styles.Default));

   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance
   is (Normal     => Palette.Content,
       Selected   => Palette.Selected,
       Detail     => Palette.Muted,
       Counter    => Palette.Muted,
       Categories => (others => Flyology_TUI.Styles.Default));

   function Create
     (Mode     : Presentation_Mode;
      Width    : Natural;
      Max_Rows : Natural) return Model is
   begin
      return Result : Model do
         Result.Shape := Mode;
         Result.Cells := Width;
         Result.Rows := Max_Rows;
      end return;
   end Create;

   function Display_Of (Item : Candidate) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Display));

   function Detail_Of (Item : Candidate) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Detail));

   function Insert_Of (Item : Candidate) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Insert));

   function Length (Item : Model) return Natural
   is (Natural (Item.Values.Length));

   function Is_Empty (Item : Model) return Boolean
   is (Item.Values.Is_Empty);

   function Candidate_At
     (Item : Model; Position : Positive) return Candidate
   is (Item.Values (Position));

   function Selected_Index (Item : Model) return Natural is (Item.Selected);

   function Selected_Candidate (Item : Model) return Candidate
   is (Item.Values (Item.Selected));

   function Replacement_First (Item : Model) return Natural
   is (Item.First_Cut);

   function Replacement_Last (Item : Model) return Natural
   is (Item.Last_Cut);

   function Is_Open (Item : Model) return Boolean is (Item.Opened);

   function Mode (Item : Model) return Presentation_Mode is (Item.Shape);

   function Width (Item : Model) return Natural is (Item.Cells);

   function Max_Rows (Item : Model) return Natural is (Item.Rows);

   --  Longest prefix of Value whose rendered width fits Cells, cut on a
   --  grapheme-cluster boundary so a clipped candidate never splits one.
   function Truncate
     (Value : Wide_Wide_String; Cells : Natural) return Wide_Wide_String
   is
      Position : Natural := Value'First;
      Used     : Natural := 0;
      Last     : Natural := Value'First - 1;
   begin
      while Position <= Value'Last loop
         declare
            Stop : constant Natural :=
              Flyology_TUI.Glyphs.Cluster_Last (Value, Position);
            Span : constant Natural :=
              Flyology_TUI.Glyphs.Width_Of (Value (Position .. Stop));
         begin
            exit when Used + Span > Cells;
            Used := Used + Span;
            Last := Stop;
            Position := Stop + 1;
         end;
      end loop;
      return Value (Value'First .. Last);
   end Truncate;

   ---------------------------------------------------------------------
   --  Geometry
   ---------------------------------------------------------------------

   --  Published shape of the popup. It depends only on the candidate set
   --  and the agreed cells, never on the scroll offset, so Ensure_Visible
   --  can consult it before the offset is corrected.
   procedure Shape_Of
     (Item         : Model;
      Column_Cells : out Natural;
      Column_Count : out Natural;
      Row_Count    : out Natural;
      Counter      : out Boolean)
   is
      Count  : constant Natural := Length (Item);
      Widest : Natural := 1;
      Needed : Natural;
   begin
      Column_Cells := 0;
      Column_Count := 0;
      Row_Count := 0;
      Counter := False;
      if Count = 0 or else Item.Cells = 0 or else Item.Rows = 0 then
         return;
      end if;

      case Item.Shape is
         when Detailed_Menu =>
            Column_Count := 1;
            Column_Cells := Item.Cells;
            Needed := Count;
         when Tabulated_Grid =>
            for Position in 1 .. Count loop
               Widest :=
                 Natural'Max
                   (Widest,
                    Flyology_TUI.Glyphs.Width_Of
                      (Display_Of (Item.Values (Position))));
            end loop;
            Column_Cells := Mark_Cells + Widest + Column_Gap;
            --  The final column carries no trailing gutter.
            Column_Count :=
              Natural'Max (1, (Item.Cells + Column_Gap) / Column_Cells);
            Needed := (Count + Column_Count - 1) / Column_Count;
      end case;

      if Needed <= Item.Rows then
         Row_Count := Needed;
      elsif Item.Rows >= 2 then
         --  Reserve the last row for the clipped-candidate counter.
         Counter := True;
         Row_Count := Item.Rows - 1;
      else
         Row_Count := Item.Rows;
      end if;
   end Shape_Of;

   procedure Ensure_Visible (Item : in out Model) is
      Count : constant Natural := Length (Item);
      Column_Cells, Column_Count, Row_Count : Natural;
      Counter : Boolean;
   begin
      Shape_Of (Item, Column_Cells, Column_Count, Row_Count, Counter);
      if Row_Count = 0 or else Item.Selected = 0 then
         Item.Offset := 0;
         return;
      end if;
      case Item.Shape is
         when Detailed_Menu =>
            if Item.Selected <= Item.Offset then
               Item.Offset := Item.Selected - 1;
            elsif Item.Selected > Item.Offset + Row_Count then
               Item.Offset := Item.Selected - Row_Count;
            end if;
            --  Growing the popup must not leave a window past the end.
            Item.Offset :=
              Natural'Min
                (Item.Offset,
                 (if Count > Row_Count then Count - Row_Count else 0));
         when Tabulated_Grid =>
            declare
               Total_Columns : constant Natural :=
                 (Count + Row_Count - 1) / Row_Count;
               Last_Column : constant Natural :=
                 (if Total_Columns > Column_Count
                  then Total_Columns - Column_Count else 0);
               Selected_Column : constant Natural :=
                 (Item.Selected - 1) / Row_Count;
               First_Column : Natural := Item.Offset / Row_Count;
            begin
               if Selected_Column < First_Column then
                  First_Column := Selected_Column;
               elsif Selected_Column > First_Column + Column_Count - 1 then
                  First_Column := Selected_Column - (Column_Count - 1);
               end if;
               Item.Offset :=
                 Natural'Min (First_Column, Last_Column) * Row_Count;
            end;
      end case;
   end Ensure_Visible;

   function Layout (Item : Model) return Presentation is
      Count : constant Natural := Length (Item);
      Result : Presentation;
      Column_Cells, Column_Count, Row_Count : Natural;
      Counter : Boolean;
      Capacity_Cells : Natural;
   begin
      Shape_Of (Item, Column_Cells, Column_Count, Row_Count, Counter);
      Result.Shape := Item.Shape;
      Result.Cells := Item.Cells;
      Result.Column_Cells := Column_Cells;
      Result.Column_Count := Column_Count;
      Result.Row_Count := Row_Count;
      Result.Counter := Counter;
      Result.Offset := Item.Offset;
      Capacity_Cells :=
        (if Item.Shape = Detailed_Menu then Row_Count
         else Row_Count * Column_Count);
      if Capacity_Cells = 0 or else Item.Offset >= Count then
         Result.Visible := 0;
      else
         Result.Visible :=
           Natural'Min (Capacity_Cells, Count - Item.Offset);
      end if;
      Result.Hidden := Count - Result.Visible;
      return Result;
   end Layout;

   function Height (Item : Presentation) return Natural
   is (Item.Row_Count + (if Item.Counter then 1 else 0));

   function Columns (Item : Presentation) return Natural
   is (Item.Column_Count);

   function Content_Rows (Item : Presentation) return Natural
   is (Item.Row_Count);

   function First_Visible (Item : Presentation) return Natural
   is (Item.Offset);

   function Visible_Count (Item : Presentation) return Natural
   is (Item.Visible);

   function Hidden_Count (Item : Presentation) return Natural
   is (Item.Hidden);

   function Has_Counter_Row (Item : Presentation) return Boolean
   is (Item.Counter);

   function Position_At_Cell
     (Item : Presentation; X, Y : Natural) return Natural
   is
      Column : Natural;
      Result : Natural;
   begin
      if Y >= Item.Row_Count
        or else X >= Item.Cells
        or else Item.Visible = 0
      then
         return 0;
      end if;
      case Item.Shape is
         when Detailed_Menu =>
            Column := 0;
         when Tabulated_Grid =>
            if Item.Column_Cells = 0 then
               return 0;
            end if;
            Column := X / Item.Column_Cells;
            --  The trailing gutter of a column is drawn by nothing, so it
            --  must not activate the candidate beside it.
            if Column >= Item.Column_Count
              or else X mod Item.Column_Cells
                      >= Item.Column_Cells - Column_Gap
            then
               return 0;
            end if;
      end case;
      Result := Item.Offset + Column * Item.Row_Count + Y + 1;
      if Result > Item.Offset + Item.Visible then
         return 0;
      end if;
      return Result;
   end Position_At_Cell;

   ---------------------------------------------------------------------
   --  Candidate set
   ---------------------------------------------------------------------

   function Offer
     (Item          : in out Model;
      Values        : Candidate_Array;
      Replace_First : Natural;
      Replace_Last  : Natural) return Offer_Result
   is
      Accepted : Natural;
   begin
      if Replace_Last < Replace_First then
         return Rejected_Span;
      end if;

      Item.Values.Clear;
      Item.Selected := 0;
      Item.Offset := 0;
      Item.First_Cut := Replace_First;
      Item.Last_Cut := Replace_Last;

      if Values'Length = 0 then
         Item.Opened := False;
         return Closed_Empty;
      end if;

      Accepted := Natural'Min (Values'Length, Capacity);
      for Index in 0 .. Accepted - 1 loop
         Item.Values.Append (Values (Values'First + Index));
      end loop;
      Item.Opened := True;
      Item.Selected := 1;
      Ensure_Visible (Item);
      return (if Accepted < Values'Length then Offered_Truncated
              else Offered);
   end Offer;

   procedure Close (Item : in out Model) is
   begin
      Item.Opened := False;
      Item.Values.Clear;
      Item.Selected := 0;
      Item.Offset := 0;
   end Close;

   function Dismiss
     (Item : in out Model)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if not Item.Opened then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      Close (Item);
      Result.Handled := True;
      Result.Changed := True;
      Result.Capture := Flyology_TUI.Components.Interactions.Release_Capture;
      return Result;
   end Dismiss;

   function Common_Prefix (Item : Model) return Wide_Wide_String is
      Count : constant Natural := Length (Item);
   begin
      if Count = 0 then
         return "";
      end if;
      declare
         Leader : constant Wide_Wide_String :=
           Insert_Of (Item.Values (1));
         Shared : Natural := Leader'Length;
         Boundary : Natural := 0;
         Position : Natural := Leader'First;
      begin
         for Index in 2 .. Count loop
            declare
               Other : constant Wide_Wide_String :=
                 Insert_Of (Item.Values (Index));
               Limit : constant Natural :=
                 Natural'Min (Shared, Other'Length);
            begin
               Shared := 0;
               for Step in 1 .. Limit loop
                  exit when Leader (Leader'First + Step - 1)
                    /= Other (Other'First + Step - 1);
                  Shared := Step;
               end loop;
               exit when Shared = 0;
            end;
         end loop;
         --  Cut back to a cluster boundary of the leading candidate.
         while Position <= Leader'Last loop
            declare
               Stop : constant Natural :=
                 Flyology_TUI.Glyphs.Cluster_Last (Leader, Position);
               Span : constant Natural := Stop - Leader'First + 1;
            begin
               exit when Span > Shared;
               Boundary := Span;
               Position := Stop + 1;
            end;
         end loop;
         return Leader (Leader'First .. Leader'First + Boundary - 1);
      end;
   end Common_Prefix;

   ---------------------------------------------------------------------
   --  Selection
   ---------------------------------------------------------------------

   procedure Select_Next (Item : in out Model) is
      Count : constant Natural := Length (Item);
   begin
      if Count = 0 then
         Item.Selected := 0;
         return;
      end if;
      Item.Selected := (Item.Selected mod Count) + 1;
      Ensure_Visible (Item);
   end Select_Next;

   procedure Select_Previous (Item : in out Model) is
      Count : constant Natural := Length (Item);
   begin
      if Count = 0 then
         Item.Selected := 0;
         return;
      end if;
      Item.Selected := (if Item.Selected <= 1 then Count
                        else Item.Selected - 1);
      Ensure_Visible (Item);
   end Select_Previous;

   procedure Select_First (Item : in out Model) is
   begin
      if Length (Item) = 0 then
         Item.Selected := 0;
      else
         Item.Selected := 1;
      end if;
      Ensure_Visible (Item);
   end Select_First;

   procedure Select_Last (Item : in out Model) is
   begin
      Item.Selected := Length (Item);
      Ensure_Visible (Item);
   end Select_Last;

   --  Move Step candidates, wrapping through the whole set.
   procedure Move_By (Item : in out Model; Step : Integer) is
      Count : constant Natural := Length (Item);
   begin
      if Count = 0 then
         Item.Selected := 0;
         return;
      end if;
      Item.Selected :=
        Natural (((Integer (Item.Selected) - 1 + Step) mod Count) + 1);
      Ensure_Visible (Item);
   end Move_By;

   function Column_Step (Item : Model) return Positive is
      Column_Cells, Column_Count, Row_Count : Natural;
      Counter : Boolean;
   begin
      Shape_Of (Item, Column_Cells, Column_Count, Row_Count, Counter);
      return (if Row_Count = 0 then 1 else Row_Count);
   end Column_Step;

   procedure Select_Next_Column (Item : in out Model) is
   begin
      Move_By (Item, Column_Step (Item));
   end Select_Next_Column;

   procedure Select_Previous_Column (Item : in out Model) is
   begin
      Move_By (Item, -Column_Step (Item));
   end Select_Previous_Column;

   procedure Select_Position (Item : in out Model; Position : Natural) is
   begin
      Item.Selected := Position;
      Ensure_Visible (Item);
   end Select_Position;

   procedure Set_Mode (Item : in out Model; Mode : Presentation_Mode) is
   begin
      Item.Shape := Mode;
      Ensure_Visible (Item);
   end Set_Mode;

   procedure Set_Size
     (Item : in out Model; Width : Natural; Max_Rows : Natural) is
   begin
      Item.Cells := Width;
      Item.Rows := Max_Rows;
      Ensure_Visible (Item);
   end Set_Size;

   ---------------------------------------------------------------------
   --  Interaction
   ---------------------------------------------------------------------

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if not Item.Opened or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      --  A popup with no published geometry is hidden, so it must not keep
      --  modal keyboard behavior over an application that cannot see it.
      if Height (Layout (Item)) = 0 then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      Result.Handled := True;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Select_Next (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Select_Previous (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Arrow_Right_Key =>
            Select_Next_Column (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Arrow_Left_Key =>
            Select_Previous_Column (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Page_Down_Key =>
            Select_Next_Column (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Page_Up_Key =>
            Select_Previous_Column (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Home_Key =>
            Select_First (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.End_Key =>
            Select_Last (Item);
            Result.Changed := True;
         when Flyology_TUI.Events.Tab_Key =>
            if Event.Key.Modified.Shift then
               Select_Previous (Item);
            else
               Select_Next (Item);
            end if;
            Result.Changed := True;
         when Flyology_TUI.Events.Enter_Key =>
            if Item.Selected = 0 then
               Result.Handled := False;
            else
               Result.Activated := True;
            end if;
         when Flyology_TUI.Events.Escape_Key =>
            Close (Item);
            Result.Changed := True;
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Release_Capture;
         when others =>
            Result.Handled := False;
      end case;
      return Result;
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Shape  : constant Presentation := Layout (Item);
      Target : Natural;
   begin
      if not Item.Opened or else Height (Shape) = 0 then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;

      if Event.Action = Flyology_TUI.Events.Mouse_Wheel then
         if Event.Wheel_Y < 0 then
            Select_Next (Item);
            Result.Handled := True;
            Result.Changed := True;
         elsif Event.Wheel_Y > 0 then
            Select_Previous (Item);
            Result.Handled := True;
            Result.Changed := True;
         end if;
         return Result;
      end if;

      if Event.X < 0 or else Event.Y < 0 then
         return Result;
      end if;

      Target := Position_At_Cell (Shape, Natural (Event.X), Natural (Event.Y));
      if Target = 0 then
         return Result;
      end if;

      case Event.Action is
         when Flyology_TUI.Events.Mouse_Click =>
            if Event.Button = Flyology_TUI.Events.Left_Button then
               Select_Position (Item, Target);
               Result.Handled := True;
               Result.Changed := True;
               Result.Activated := True;
            end if;
         when Flyology_TUI.Events.Mouse_Move
            | Flyology_TUI.Events.Mouse_Drag =>
            if Target /= Item.Selected then
               Select_Position (Item, Target);
               Result.Handled := True;
               Result.Changed := True;
            end if;
         when others =>
            null;
      end case;
      return Result;
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
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin
      null;
   end Update;

   ---------------------------------------------------------------------
   --  Rendering
   ---------------------------------------------------------------------

   function Image (Value : Natural) return Wide_Wide_String is
      Raw : constant String := Natural'Image (Value);
      Trimmed : constant String := Raw (Raw'First + 1 .. Raw'Last);
      Result : Wide_Wide_String (Trimmed'Range);
   begin
      for Index in Trimmed'Range loop
         Result (Index) := Wide_Wide_Character'Val
           (Character'Pos (Trimmed (Index)));
      end loop;
      return Result;
   end Image;

   function Render
     (Item : Model; Look : Appearance)
      return Flyology_TUI.Surfaces.Surface
   is
      Shape : constant Presentation := Layout (Item);
      Rows : constant Natural := Height (Shape);
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Cells, Rows, Look.Normal);
   begin
      if Item.Cells = 0 or else Rows = 0 then
         return Result;
      end if;

      for Index in 1 .. Shape.Visible loop
         declare
            Position : constant Positive := Shape.Offset + Index;
            Value : constant Candidate := Item.Values (Position);
            Column : constant Natural := (Index - 1) / Shape.Row_Count;
            Row : constant Natural := (Index - 1) mod Shape.Row_Count;
            Chosen : constant Boolean := Position = Item.Selected;
            Origin : constant Natural := Column * Shape.Column_Cells;
            Room : constant Natural :=
              (if Origin >= Item.Cells then 0 else Item.Cells - Origin);
            Look_Normal : constant Flyology_TUI.Styles.Style :=
              Flyology_TUI.Styles.Inherit_Colors
                (Look.Categories (Value.Kind), Look.Normal);
            Body_Style : constant Flyology_TUI.Styles.Style :=
              (if Chosen then Look.Selected else Look_Normal);
         begin
            exit when Room = 0;
            case Item.Shape is
               when Tabulated_Grid =>
                  declare
                     Mark : constant Wide_Wide_String :=
                       (if Chosen then Selected_Mark else Unselected_Mark);
                     Marked : constant Natural :=
                       Natural'Min (Room, Mark_Cells);
                  begin
                     Result.Write
                       (Origin, Row, Truncate (Mark, Marked), Body_Style);
                     Result.Write
                       (Origin + Marked,
                        Row,
                        Truncate
                          (Display_Of (Value),
                           Natural'Min
                             (Room - Marked,
                              Shape.Column_Cells - Column_Gap
                              - Mark_Cells)),
                        Body_Style);
                  end;
               when Detailed_Menu =>
                  declare
                     Mark : constant Wide_Wide_String :=
                       (if Chosen then Selected_Mark else Unselected_Mark);
                     Mark_Cells : constant Natural :=
                       Natural'Min (Room, Mark'Length);
                     Detail : constant Wide_Wide_String :=
                       Detail_Of (Value);
                     Left : constant Natural := Room - Mark_Cells;
                     Detail_Cells : Natural := 0;
                  begin
                     Result.Write
                       (Origin,
                        Row,
                        Truncate (Mark, Mark_Cells),
                        Body_Style);
                     if Detail'Length > 0 and then Left > 2 then
                        Detail_Cells :=
                          Natural'Min
                            (Flyology_TUI.Glyphs.Width_Of (Detail),
                             Left / 2);
                     end if;
                     Result.Write
                       (Origin + Mark_Cells,
                        Row,
                        Truncate
                          (Display_Of (Value),
                           (if Detail_Cells = 0 then Left
                            else Left - Detail_Cells - 1)),
                        Body_Style);
                     if Detail_Cells > 0 then
                        Result.Write
                          (Item.Cells - Detail_Cells,
                           Row,
                           Truncate (Detail, Detail_Cells),
                           Look.Detail);
                     end if;
                  end;
            end case;
         end;
      end loop;

      if Shape.Counter then
         Result.Write
           (0,
            Shape.Row_Count,
            Truncate
              ("+" & Image (Shape.Hidden) & " more", Item.Cells),
            Look.Counter);
      end if;
      return Result;
   end Render;

   function Render
     (Item : Model; Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, From_Theme (Theme)));

end Flyology_TUI.Components.Completions;
