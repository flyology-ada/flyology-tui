with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Text_IO;
with Flyology_TUI.Components;
with Flyology_TUI.Components.Breadcrumbs;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Components.Tables;
with Flyology_TUI.Components.Trees;
with Flyology_TUI.Events;
with Flyology_TUI.Geometry;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

procedure Data_Navigation_Tests is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Styles.Style;

   type Row is record
      Id    : Natural;
      Group : Natural;
      Score : Natural;
   end record;
   type Column is (Name_Column, Score_Column);

   function Row_Id (Item : Row) return Natural is (Item.Id);
   function Row_Label (Item : Row) return Wide_Wide_String is
     (case Item.Id is
         when 1 => "Alpha",
         when 2 => "βeta",
         when 3 => "界面",
         when 4 => "Delta",
         when others => "Extra");
   function Row_Cell (Item : Row; Which : Column) return Wide_Wide_String is
     (case Which is
         when Name_Column => Row_Label (Item),
         when Score_Column =>
           (if Item.Id = 3 or else Item.Id = 4 then ""
            else (case Item.Score is
                     when 10 => "10",
                     when 20 => "20",
                     when 30 => "30",
                     when others => "40")));
   function Row_Less
     (Left, Right : Row; Which : Column) return Boolean is
     (case Which is
         when Name_Column => Left.Group < Right.Group,
         when Score_Column => Left.Score < Right.Score);

   package Tables is new Flyology_TUI.Components.Tables
     (Item_Type => Row,
      Id_Type   => Natural,
      Column_Id => Column,
      Id_Of     => Row_Id,
      Cell      => Row_Cell,
      Less      => Row_Less,
      Capacity  => 4);
   use type Tables.Sort_Direction;
   use type Tables.Focus_Area;

   type Node is record
      Id    : Natural;
      Depth : Natural;
   end record;
   function Node_Id (Item : Node) return Natural is (Item.Id);
   function Node_Label (Item : Node) return Wide_Wide_String is
     (case Item.Id is
         when 1 => "Root",
         when 2 => "Child",
         when 3 => "孫",
         when 4 => "Peer",
         when 5 => "Other",
         when others => "Extra");
   function Node_Depth (Item : Node) return Natural is (Item.Depth);

   package Trees is new Flyology_TUI.Components.Trees
     (Item_Type => Node,
      Id_Type   => Natural,
      Id_Of     => Node_Id,
      Label     => Node_Label,
      Depth_Of  => Node_Depth,
      Capacity  => 5);

   package Breadcrumbs is new Flyology_TUI.Components.Breadcrumbs
     (Item_Type => Row,
      Id_Type   => Natural,
      Id_Of     => Row_Id,
      Label     => Row_Label,
      Capacity  => 4);

   R1 : constant Row := (Id => 1, Group => 2, Score => 30);
   R2 : constant Row := (Id => 2, Group => 1, Score => 10);
   R3 : constant Row := (Id => 3, Group => 1, Score => 20);
   R4 : constant Row := (Id => 4, Group => 3, Score => 40);

   Columns : constant Tables.Column_Definitions :=
     (Name_Column =>
        (Heading       => Text.To_Unbounded_Wide_Wide_String ("Name"),
         Width         => 7,
         Minimum_Width => 3,
         Align         => Tables.Align_Left,
         Sortable      => True),
      Score_Column =>
        (Heading       => Text.To_Unbounded_Wide_Wide_String ("Score"),
         Width         => 5,
         Minimum_Width => 2,
         Align         => Tables.Align_Right,
         Sortable      => True));

   procedure Assert (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Assert;

   function Key (Kind : Flyology_TUI.Events.Key_Kind)
      return Flyology_TUI.Events.Terminal_Event
   is
      Value : Flyology_TUI.Events.Key_Event (Kind);
   begin
      Value.Modified := (others => False);
      Value.Repeated := False;
      return Flyology_TUI.Events.Pressed (Value);
   end Key;

   function Space return Flyology_TUI.Events.Terminal_Event is
     (Flyology_TUI.Events.Pressed
        ((Kind     => Flyology_TUI.Events.Text_Key,
          Modified => (others => False),
          Repeated => False,
          Value    => Text.To_Unbounded_Wide_Wide_String (" "))));

   function Glyph
     (Item : Flyology_TUI.Surfaces.Surface; X, Y : Natural)
      return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Element (X, Y).Glyph));

   function Mouse
     (X, Y    : Integer;
      Action  : Flyology_TUI.Events.Mouse_Action;
      Button  : Flyology_TUI.Events.Mouse_Button :=
        Flyology_TUI.Events.Left_Button;
      Wheel_Y : Integer := 0) return Flyology_TUI.Mouse.Local_Event is
     (X        => X,
      Y        => Y,
      Button   => Button,
      Action   => Action,
      Modified => (others => False),
      Wheel_X  => 0,
      Wheel_Y  => Wheel_Y);

   procedure Test_Tables is
      Item : Tables.Model := Tables.Create ((R1, R2, R3), Columns, 2);
      Empty : constant Tables.Model := Tables.Create
        (Tables.Item_Array'(1 .. 0 => R1), Columns, 0);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : Flyology_TUI.Styles.Style;
      Frame  : Flyology_TUI.Surfaces.Surface;
      Raised : Boolean := False;
      Before_Id : Natural;
   begin
      Item.Sort_By (Name_Column, Tables.Ascending);
      Assert
        (Item.Row_Id (1) = 2 and then Item.Row_Id (2) = 3
         and then Item.Row_Id (3) = 1,
         "ascending table sort is not stable");
      Item.Sort_By (Name_Column, Tables.Descending);
      Assert
        (Item.Row_Id (1) = 1 and then Item.Row_Id (2) = 2
         and then Item.Row_Id (3) = 3,
         "descending table sort is not stable");

      Item.Select_Id (2);
      Item.Sort_By (Name_Column, Tables.Ascending);
      Assert
        (Item.Focused_Id = 2 and then Item.Selected_Id = 2,
         "sorting changed the focused or selected row identity");
      Item.Set_Rows ((R3, R1, R2));
      Assert
        (Item.Selected_Id = 2 and then Item.Focused_Id = 2,
         "table selection or focus did not follow its stable ID");
      Item.Sort_By (Score_Column, Tables.Unsorted);
      Result := Item.Handle
        (Mouse
           (Item.Column_Region (Score_Column).X, 0,
            Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Handled and then Result.Changed and then Result.Activated
         and then Item.Sort.Direction = Tables.Ascending
         and then Item.Sort.Column = Score_Column,
         "sortable table header did not apply ascending order");
      Result := Item.Handle
        (Mouse
           (Item.Column_Region (Score_Column).X, 0,
            Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Activated and then Item.Sort.Direction = Tables.Descending,
         "second table header click did not reverse order");
      Result := Item.Handle
        (Mouse
           (Item.Column_Region (Score_Column).X, 0,
            Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Activated and then Item.Sort.Direction = Tables.Unsorted,
         "third table header click did not clear sorting");

      Item.Select_Id (Item.Row_Id (1));
      Before_Id := Item.Selected_Id;
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Assert
        (Result.Changed and then Item.Focus_Zone = Tables.Header_Area
         and then Item.Selected_Id = Before_Id,
         "table keyboard focus could not enter the header stably");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (Result.Handled and then Item.Focused_Column = Score_Column,
         "table header keyboard navigation did not select a column");
      Item.Sort_By (Score_Column, Tables.Unsorted);
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Sort.Direction = Tables.Ascending,
         "table header Enter did not start ascending sorting");
      Result := Item.Handle (Space);
      Assert
        (Result.Activated and then Item.Sort.Direction = Tables.Descending,
         "table header Space did not reverse sorting");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Item.Sort.Direction = Tables.Unsorted,
         "table keyboard sort cycle did not return to unsorted");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Item.Focus_Zone = Tables.Row_Area
         and then Item.Selected_Id = Before_Id,
         "table keyboard focus did not return to stable row selection");

      Item.Select_Id (Item.Row_Id (1));
      Before_Id := Item.Selected_Id;
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'Last));
      Assert
        (Result.Handled and then Result.Changed and then Result.Focus_Requested
         and then Item.Focus_Zone = Tables.Row_Area
         and then Item.Selected_Id = Before_Id,
         "table wheel leaving header focus lost its zone-only change");

      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      declare
         Before_Column : constant Column := Item.Focused_Column;
         Divider_X : constant Integer :=
           Item.Column_Region (Name_Column).X +
             Integer (Item.Column_Region (Name_Column).Width);
      begin
         Result := Item.Handle
           (Mouse (Divider_X, 0, Flyology_TUI.Events.Mouse_Click));
         Assert
           (not Result.Handled and then Item.Focused_Column = Before_Column,
            "table divider click changed the focused header column");
      end;

      Result := Item.Handle
        (Mouse (1, 1, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Activated and then Result.Focus_Requested,
         "table row click was not activated or focused");
      Result := Item.Handle (Key (Flyology_TUI.Events.Page_Down_Key));
      Assert (Result.Handled, "table did not handle page navigation");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'First));
      Assert
        (Result.Handled and then Result.Focus_Requested
         and then Item.Focused_Id = Item.Row_Id (Item.Length),
         "extreme table wheel input did not saturate at the end");
      Result := Item.Handle
        (Mouse
           (-1, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'Last));
      Assert (not Result.Handled,
              "table handled an extreme wheel event outside its region");

      Item.Select_Id (2);
      Before_Id := Item.Selected_Id;
      begin
         Item.Select_Id (99);
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Id = Before_Id,
         "missing table ID changed selection before failing");
      Raised := False;
      Item.Set_Enabled (False);
      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert (not Result.Handled and then Item.Selected_Id = Before_Id,
              "disabled table accepted keyboard input");
      Result := Item.Handle
        (Mouse
           (0, 1, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'First));
      Assert (not Result.Handled and then Item.Selected_Id = Before_Id,
              "disabled table accepted mouse input");
      Frame := Item.Render
        (Theme => Flyology_TUI.Themes.Charm, Has_Focus => True);
      Assert
        (Frame.Element (0, 0).Appearance = Flyology_TUI.Themes.Charm.Muted
         and then Frame.Element
           (Natural (Item.Column_Region (Name_Column).X), 0).Appearance =
             Flyology_TUI.Themes.Charm.Muted
         and then Frame.Element
           (Natural (Item.Column_Region (Name_Column).X) +
              Item.Column_Region (Name_Column).Width,
            0).Appearance = Flyology_TUI.Themes.Charm.Muted,
         "disabled table header retained active control styling");
      Item.Set_Enabled (True);

      begin
         Item.Set_Rows ((R1, R2, R2));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 3 and then Item.Selected_Id /= 0,
         "duplicate table IDs did not fail atomically");
      Raised := False;
      begin
         Item.Set_Rows ((R1, R2, R3, R4, (Id => 5, Group => 4, Score => 40)));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 3,
         "table capacity failure mutated the rows");
      Raised := False;
      declare
         Old_Rows : constant Natural := Item.Viewport_Rows;
      begin
         begin
            Item.Set_Viewport_Rows (Natural'Last);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Item.Viewport_Rows = Old_Rows,
            "table Natural'Last height failure was not atomic");
      end;
      Raised := False;
      declare
         Huge : Tables.Column_Definitions := Columns;
         Old_Width : constant Natural := Item.Width;
      begin
         Huge (Name_Column).Width := Natural'Last;
         begin
            Item.Set_Columns (Huge);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Item.Width = Old_Width,
            "table overflowing columns changed dimensions before failing");
      end;
      Raised := False;
      begin
         declare
            Too_Tall : constant Tables.Model :=
              Tables.Create ((R1, R2), Columns, Natural'Last);
            pragma Unreferenced (Too_Tall);
         begin
            null;
         end;
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert (Raised,
              "table creation accepted an overflowing Natural'Last height");
      Raised := False;
      declare
         Minimal : constant Tables.Column_Definitions :=
           (others =>
              (Heading       => Text.Null_Unbounded_Wide_Wide_String,
               Width         => 0,
               Minimum_Width => 1,
               Align         => Tables.Align_Left,
               Sortable      => False));
      begin
         begin
            declare
               Product_Overflow : constant Tables.Model :=
                 Tables.Create
                   (Tables.Item_Array'(1 => R1), Minimal, Natural'Last - 1);
               pragma Unreferenced (Product_Overflow);
            begin
               null;
            end;
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
      end;
      Assert (Raised,
              "table accepted a width-by-height allocation overflow");

      Assert
        (Empty.Is_Empty and then Empty.Visible_Row_Count = 0
         and then Empty.Render
           (Theme => Flyology_TUI.Themes.Charm).Height = 1,
         "empty zero-row table was not renderable");
      Frame := Item.Render
        (Look => Tables.Appearance'
           (Header   => Flyology_TUI.Themes.Charm.Error,
          Normal   => Flyology_TUI.Themes.Charm.Success,
          Selected => Flyology_TUI.Themes.Charm.Selected,
          Focused  => Flyology_TUI.Themes.Charm.Focused,
          Muted    => Flyology_TUI.Themes.Charm.Muted,
          Divider  => Flyology_TUI.Themes.Charm.Border));
      Before := Frame.Element (0, 0).Appearance;
      Assert
        (Before = Flyology_TUI.Themes.Charm.Error,
         "table ignored an explicit header appearance");
      Result := Item.Handle
        (Mouse
           (Item.Column_Region (Score_Column).X, 0,
            Flyology_TUI.Events.Mouse_Click));
      Frame := Item.Render
        (Look => Tables.Appearance'
           (Header   => Flyology_TUI.Themes.Charm.Error,
            Normal   => Flyology_TUI.Themes.Charm.Success,
            Selected => Flyology_TUI.Themes.Charm.Selected,
            Focused  => Flyology_TUI.Themes.Charm.Focused,
            Muted    => Flyology_TUI.Themes.Charm.Muted,
            Divider  => Flyology_TUI.Themes.Charm.Border),
         Has_Focus => True);
      Assert
        (Frame.Element
           (Natural (Item.Column_Region (Score_Column).X), 0).Appearance =
           Flyology_TUI.Themes.Charm.Focused,
         "table did not render keyboard/mouse header focus distinctly");
      Item.Sort_By (Name_Column, Tables.Unsorted);
      Item.Select_Id (Item.Row_Id (1));
      Frame := Item.Render
        (Look => Tables.Appearance'
           (Header   => Flyology_TUI.Themes.Charm.Error,
            Normal   => Flyology_TUI.Themes.Charm.Success,
            Selected => Flyology_TUI.Themes.Charm.Selected,
            Focused  => Flyology_TUI.Themes.Charm.Focused,
            Muted    => Flyology_TUI.Themes.Charm.Muted,
            Divider  => Flyology_TUI.Themes.Charm.Border),
         Has_Focus => True);
      Assert
        (Frame.Element
           (Natural (Item.Column_Region (Name_Column).X), 1).Appearance =
           Flyology_TUI.Themes.Charm.Focused,
         "table row area did not render its focused row");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Up_Key));
      Frame := Item.Render
        (Look => Tables.Appearance'
           (Header   => Flyology_TUI.Themes.Charm.Error,
            Normal   => Flyology_TUI.Themes.Charm.Success,
            Selected => Flyology_TUI.Themes.Charm.Selected,
            Focused  => Flyology_TUI.Themes.Charm.Focused,
            Muted    => Flyology_TUI.Themes.Charm.Muted,
            Divider  => Flyology_TUI.Themes.Charm.Border),
         Has_Focus => True);
      Assert
        (Frame.Element
           (Natural (Item.Column_Region (Name_Column).X), 1).Appearance =
           Flyology_TUI.Themes.Charm.Selected,
         "table header focus leaked focused styling into the selected row");
      Assert
        (Tables.From_Theme (Flyology_TUI.Themes.Charm).Selected =
           Flyology_TUI.Themes.Charm.Selected,
         "table theme mapping changed selected semantics");
      Assert
        (Frame.Width > 0,
         "Unicode table cells collapsed the table geometry");
      declare
         Tiny_Columns : constant Tables.Column_Definitions :=
           (Name_Column =>
              (Heading       => Text.To_Unbounded_Wide_Wide_String ("Long"),
               Width         => 2,
               Minimum_Width => 0,
               Align         => Tables.Align_Left,
               Sortable      => False),
            Score_Column =>
              (Heading       => Text.Null_Unbounded_Wide_Wide_String,
               Width         => 2,
               Minimum_Width => 0,
               Align         => Tables.Align_Left,
               Sortable      => False));
         Tiny : constant Tables.Model := Tables.Create
           (Tables.Item_Array'(1 => R3), Tiny_Columns, 1);
         Tiny_Frame : constant Flyology_TUI.Surfaces.Surface :=
           Tiny.Render (Theme => Flyology_TUI.Themes.Charm);
      begin
         Assert
           (Tiny_Frame.Width = 7 and then Tiny_Frame.Height = 2,
            "tiny table rendering changed its declared geometry");
         Assert
           (Glyph (Tiny_Frame, 5, 0) = " "
            and then Glyph (Tiny_Frame, 5, 1) = " "
            and then not Tiny_Frame.Element (5, 1).Continuation,
            "overlong or wide table cell bled into the following " &
            "blank column");
      end;
   end Test_Tables;

   procedure Test_Trees is
      Base : constant Trees.Item_Array :=
        ((Id => 1, Depth => 0),
         (Id => 2, Depth => 1),
         (Id => 3, Depth => 2),
         (Id => 4, Depth => 1),
         (Id => 5, Depth => 0));
      Item : Trees.Model := Trees.Create (Base, 3);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Raised : Boolean := False;
      Frame  : Flyology_TUI.Surfaces.Surface;
   begin
      declare
         Constrained : Breadcrumbs.Model :=
           Breadcrumbs.Create ((R1, R2, R3, R4), Maximum_Width => 20);
         Constrained_Frame : Flyology_TUI.Surfaces.Surface;
      begin
         Constrained.Set_Active (1);
         Constrained_Frame :=
           Constrained.Render (Theme => Flyology_TUI.Themes.Charm);
         Assert
           (Constrained.Item_Region (1).Width = 5
            and then Constrained.Item_Region (2).Width = 4
            and then Constrained.Item_Region (3).Width = 0
            and then Constrained.Item_Region (4).Width = 0
            and then Glyph (Constrained_Frame, 19, 0) = "…",
            "breadcrumb constrained window skipped an item or exposed " &
            "invalid regions");
      end;
      Assert
        (Item.Visible_Length = 2,
         "collapsed tree exposed descendants");
      Item.Set_Expanded (1);
      Item.Set_Expanded (2);
      Item.Select_Id (3);
      Item.Set_Expanded (1, False);
      Assert
        (Item.Selected_Id = 1,
         "collapsing a selected descendant did not select the ancestor");
      Item.Set_Expanded (1);
      Assert
        (Item.Is_Expanded (2),
         "collapsing an ancestor discarded descendant expansion state");
      Item.Select_Id (4);
      Item.Set_Nodes
        (((Id => 1, Depth => 0),
          (Id => 4, Depth => 1),
          (Id => 2, Depth => 1),
          (Id => 3, Depth => 2),
          (Id => 5, Depth => 0)));
      Assert
        (Item.Is_Expanded (1) and then Item.Is_Expanded (2)
         and then Item.Selected_Id = 4,
         "tree expansion or selection did not follow stable IDs through " &
         "reorder");

      Item.Set_Expanded (1, False);
      Item.Select_Id (1);
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert (Result.Handled, "tree rejected right-arrow navigation");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Down_Key));
      Assert
        (Result.Changed and then Item.Selected_Id = 4,
         "tree down-arrow did not select the next visible node");
      Result := Item.Handle
        (Mouse (0, 0, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Changed and then not Item.Is_Expanded (1),
         "tree disclosure click did not collapse the node");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'First));
      Assert
        (Result.Handled and then Result.Focus_Requested
         and then Item.Selected_Id = 5,
         "extreme tree wheel input did not saturate at the end");
      Result := Item.Handle
        (Mouse
           (-1, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'Last));
      Assert (not Result.Handled,
              "tree handled an extreme wheel event outside its region");
      Item.Select_Id (5);
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'Last));
      Assert
        (Result.Handled and then Item.Selected_Id = 1,
         "positive extreme tree wheel did not saturate at the start");

      begin
         Item.Select_Id (99);
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Id = 1,
         "missing tree selection ID changed state before failing");
      Raised := False;
      begin
         Item.Set_Expanded (99);
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Selected_Id = 1,
         "missing tree expansion ID changed state before failing");
      Raised := False;
      Item.Set_Enabled (False);
      Result := Item.Handle (Key (Flyology_TUI.Events.End_Key));
      Assert (not Result.Handled and then Item.Selected_Id = 1,
              "disabled tree accepted keyboard input");
      Result := Item.Handle
        (Mouse
           (0, 0, Flyology_TUI.Events.Mouse_Wheel,
            Flyology_TUI.Events.No_Button, Integer'First));
      Assert (not Result.Handled and then Item.Selected_Id = 1,
              "disabled tree accepted mouse input");
      Item.Set_Enabled (True);

      Item.Set_Expanded (1);
      declare
         Old_Rows : constant Natural := Item.Viewport_Rows;
      begin
         begin
            Item.Set_Viewport_Rows (Natural'Last);
         exception
            when Flyology_TUI.Components.Capacity_Error => Raised := True;
         end;
         Assert
           (Raised and then Item.Viewport_Rows = Old_Rows,
            "tree Natural'Last allocation failure was not atomic");
      end;
      Raised := False;
      Item.Set_Viewport_Rows (Natural'Last / Item.Width);
      Result := Item.Handle (Key (Flyology_TUI.Events.Page_Down_Key));
      Assert
        (Result.Handled and then Item.Selected_Id = 5
         and then Item.Height = Natural'Last / Item.Width,
         "large tree viewport overflowed page navigation");
      Item.Set_Viewport_Rows (3);

      begin
         Item.Set_Nodes
           (((Id => 1, Depth => 0), (Id => 2, Depth => 2)));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 5 and then Item.Selected_Id = 5,
         "tree depth-jump failure was not atomic");
      Raised := False;
      begin
         Item.Set_Nodes
           (Trees.Item_Array'(1 => (Id => 1, Depth => 1)));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Length = 5,
         "nonzero first tree depth was not rejected atomically");
      Raised := False;
      begin
         Item.Set_Nodes
           (((Id => 1, Depth => 0), (Id => 1, Depth => 0)));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert (Raised and then Item.Length = 5,
              "duplicate tree ID failure was not atomic");
      Raised := False;
      begin
         Item.Set_Nodes
           (((Id => 1, Depth => 0), (Id => 2, Depth => 0),
             (Id => 3, Depth => 0), (Id => 4, Depth => 0),
             (Id => 5, Depth => 0), (Id => 6, Depth => 0)));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert (Raised and then Item.Length = 5,
              "tree capacity failure was not atomic");

      Item.Set_Maximum_Width (1);
      Item.Set_Viewport_Rows (Natural'Last);
      begin
         Item.Set_Maximum_Width (2);
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Width = 1
         and then Item.Viewport_Rows = Natural'Last,
         "tree maximum-width allocation failure was not atomic");
      Raised := False;
      Item.Set_Viewport_Rows (3);
      Frame := Item.Render (Flyology_TUI.Themes.Charm, Has_Focus => True);
      Assert
        (Frame.Width = 1 and then Frame.Height = 3,
         "tiny Unicode tree rendering changed requested geometry");
      Assert
        (Trees.From_Theme (Flyology_TUI.Themes.Charm).Disclosure =
           Flyology_TUI.Themes.Charm.Border,
         "tree theme mapping changed disclosure semantics");
      Item.Set_Maximum_Width (20);
      Item.Select_Id (1);
      Frame := Item.Render
        (Look => Trees.Appearance'
           (Normal     => Flyology_TUI.Themes.Charm.Success,
            Selected   => Flyology_TUI.Themes.Charm.Selected,
            Focused    => Flyology_TUI.Themes.Charm.Error,
            Muted      => Flyology_TUI.Themes.Charm.Muted,
            Disclosure => Flyology_TUI.Themes.Charm.Border),
         Has_Focus => True);
      Assert
        (Frame.Element (2, 0).Appearance = Flyology_TUI.Themes.Charm.Error,
         "tree ignored its explicit focused appearance");
   end Test_Trees;

   procedure Test_Breadcrumbs is
      Item : Breadcrumbs.Model :=
        Breadcrumbs.Create ((R1, R2, R3, R4), Maximum_Width => 8);
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Region : Flyology_TUI.Geometry.Rectangle;
      Raised : Boolean := False;
      Before : Natural;
      Frame  : Flyology_TUI.Surfaces.Surface;
   begin
      Assert
        (Item.Width = 8 and then Item.Is_Visible (4),
         "breadcrumb truncation hid the focused tail");
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Left_Key));
      Assert
        (Result.Changed and then Item.Focused_Id = 3,
         "breadcrumb left arrow did not move focus by stable item");
      Result := Item.Handle (Key (Flyology_TUI.Events.Enter_Key));
      Assert
        (Result.Activated and then Item.Active_Id = 3,
         "breadcrumb Enter did not activate the focused item");
      Item.Set_Items ((R4, R3, R2, R1));
      Assert
        (Item.Active_Id = 3 and then Item.Focused_Id = 3,
         "breadcrumb active/focus IDs did not survive replacement");
      Region := Item.Item_Region (3);
      Result := Item.Handle
        (Mouse (Region.X, 0, Flyology_TUI.Events.Mouse_Click));
      Assert
        (Result.Activated and then Result.Focus_Requested,
         "breadcrumb mouse activation did not request focus");
      Before := Item.Active_Id;
      begin
         Item.Set_Active (99);
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Active_Id = Before,
         "missing breadcrumb ID changed active state before failing");
      Raised := False;
      Item.Set_Enabled (False);
      Result := Item.Handle (Key (Flyology_TUI.Events.Arrow_Right_Key));
      Assert
        (not Result.Handled and then Item.Active_Id = Before,
         "disabled breadcrumb accepted keyboard input");
      Result := Item.Handle
        (Mouse (Region.X, 0, Flyology_TUI.Events.Mouse_Click));
      Assert (not Result.Handled,
              "disabled breadcrumb accepted mouse input");

      begin
         Item.Set_Items ((R1, R2, R2));
      exception
         when Flyology_TUI.Components.Structure_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Active_Id = Before,
         "breadcrumb duplicate-ID failure was not atomic");
      Raised := False;
      begin
         Item.Set_Items ((R1, R2, R3, R4,
                          (Id => 5, Group => 5, Score => 40)));
      exception
         when Flyology_TUI.Components.Capacity_Error => Raised := True;
      end;
      Assert
        (Raised and then Item.Active_Id = Before,
         "breadcrumb capacity failure was not atomic");
      Item.Set_Enabled (True);
      Item.Set_Maximum_Width (Natural'Last);
      Frame := Item.Render
        (Look => Breadcrumbs.Appearance'
           (Normal    => Flyology_TUI.Themes.Charm.Success,
            Active    => Flyology_TUI.Themes.Charm.Error,
            Focused   => Flyology_TUI.Themes.Charm.Focused,
            Separator => Flyology_TUI.Themes.Charm.Border,
            Muted     => Flyology_TUI.Themes.Charm.Muted));
      Region := Item.Item_Region (Item.Active_Id);
      Assert
        (Frame.Element (Natural (Region.X), 0).Appearance =
           Flyology_TUI.Themes.Charm.Error,
         "breadcrumb ignored its explicit active appearance");
      Assert
        (Breadcrumbs.From_Theme (Flyology_TUI.Themes.Charm).Active =
           Flyology_TUI.Themes.Charm.Selected,
         "breadcrumb theme mapping changed active semantics");
   end Test_Breadcrumbs;

begin
   Test_Tables;
   Test_Trees;
   Test_Breadcrumbs;
   Ada.Text_IO.Put_Line ("data/navigation tests passed");
end Data_Navigation_Tests;
