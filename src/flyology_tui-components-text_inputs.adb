with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Text_Inputs is
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;

   function Create
     (Width       : Positive := 30;
      Placeholder : Wide_Wide_String := "") return Model
   is (Content     => Text.Null_Unbounded_Wide_Wide_String,
       Placeholder => Text.To_Unbounded_Wide_Wide_String (Placeholder),
       Cursor      => 0,
       Columns     => Width,
       Has_Focus   => False);

   procedure Set_Width (Item : in out Model; Width : Natural) is
   begin
      Item.Columns := Width;
   end Set_Width;

   function Width (Item : Model) return Natural is (Item.Columns);

   procedure Set_Value (Item : in out Model; Value : Wide_Wide_String) is
   begin
      Item.Content := Text.To_Unbounded_Wide_Wide_String (Value);
      Item.Cursor := Value'Length;
   end Set_Value;

   function Value (Item : Model) return Wide_Wide_String is
     (Text.To_Wide_Wide_String (Item.Content));

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   function Previous_Start
     (Value  : Wide_Wide_String;
      Cursor : Natural) return Natural
   is
      Pos : Natural := Value'First;
      Previous : Natural := 0;
   begin
      while Pos <= Value'Last and then Pos <= Cursor loop
         Previous := Pos;
         Pos := Flyology_TUI.Glyphs.Cluster_Last (Value, Pos) + 1;
      end loop;
      return Previous;
   end Previous_Start;

   procedure Replace
     (Item       : in out Model;
      First, Last : Natural;
      With_Value : Wide_Wide_String)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Result : Text.Unbounded_Wide_Wide_String;
   begin
      if First > Current'First then
         Text.Append (Result, Current (Current'First .. First - 1));
      end if;
      Text.Append (Result, With_Value);
      if Last < Current'Last then
         Text.Append (Result, Current (Last + 1 .. Current'Last));
      end if;
      Item.Content := Result;
   end Replace;

   procedure Insert
     (Item       : in out Model;
      With_Value : Wide_Wide_String) is
   begin
      Replace (Item, Item.Cursor + 1, Item.Cursor, With_Value);
      Item.Cursor := Item.Cursor + With_Value'Length;
   end Insert;

   procedure Backspace (Item : in out Model) is
      Current : constant Wide_Wide_String := Value (Item);
      First : Natural;
   begin
      if Item.Cursor = 0 then
         return;
      end if;
      First := Previous_Start (Current, Item.Cursor);
      Replace (Item, First, Item.Cursor, "");
      Item.Cursor := First - 1;
   end Backspace;

   procedure Delete (Item : in out Model) is
      Current : constant Wide_Wide_String := Value (Item);
      First : constant Natural := Item.Cursor + 1;
   begin
      if First <= Current'Last then
         Replace
           (Item,
            First,
            Flyology_TUI.Glyphs.Cluster_Last (Current, First),
            "");
      end if;
   end Delete;

   procedure Visible_Range
     (Item         : Model;
      First        : out Natural;
      Cursor_Cell  : out Natural);

   procedure Place_Cursor (Item : in out Model; Column : Natural) is
      Current : constant Wide_Wide_String := Value (Item);
      First, Cursor_Cell : Natural;
      Cell : Natural := 0;
      Pos  : Natural;
   begin
      if Current'Length = 0 then
         Item.Cursor := 0;
         return;
      end if;

      Visible_Range (Item, First, Cursor_Cell);
      pragma Unreferenced (Cursor_Cell);
      Item.Cursor := First - 1;
      Pos := First;
      while Pos <= Current'Last loop
         declare
            Last : constant Natural :=
              Flyology_TUI.Glyphs.Cluster_Last (Current, Pos);
            Width : constant Natural :=
              Natural'Max
                (1, Flyology_TUI.Glyphs.Width_Of (Current (Pos .. Last)));
         begin
            exit when Cell >= Item.Columns;
            if Column < Cell + Width then
               Item.Cursor :=
                 (if Column - Cell < (Width + 1) / 2 then Pos - 1 else Last);
               return;
            end if;
            Item.Cursor := Last;
            Cell := Cell + Width;
            Pos := Last + 1;
         end;
      end loop;
   end Place_Cursor;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
   begin
      if Event.Kind = Flyology_TUI.Events.Mouse_Input then
         if Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
           and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
           and then Event.Mouse.X < Item.Columns
           and then Event.Mouse.Y = 0
         then
            Item.Has_Focus := True;
            Place_Cursor (Item, Event.Mouse.X);
         end if;
         return;
      elsif not Item.Has_Focus then
         return;
      elsif Event.Kind = Flyology_TUI.Events.Paste then
         Insert (Item, Text.To_Wide_Wide_String (Event.Pasted_Text));
      elsif Event.Kind = Flyology_TUI.Events.Key_Press then
         case Event.Key.Kind is
            when Flyology_TUI.Events.Text_Key =>
               if not Event.Key.Modified.Control
                 and then not Event.Key.Modified.Super
               then
                  Insert (Item, Text.To_Wide_Wide_String (Event.Key.Value));
               end if;
            when Flyology_TUI.Events.Backspace_Key => Backspace (Item);
            when Flyology_TUI.Events.Delete_Key => Delete (Item);
            when Flyology_TUI.Events.Home_Key => Item.Cursor := 0;
            when Flyology_TUI.Events.End_Key =>
               Item.Cursor := Text.Length (Item.Content);
            when Flyology_TUI.Events.Arrow_Left_Key =>
               if Item.Cursor > 0 then
                  Item.Cursor :=
                    Previous_Start (Value (Item), Item.Cursor) - 1;
               end if;
            when Flyology_TUI.Events.Arrow_Right_Key =>
               if Item.Cursor < Text.Length (Item.Content) then
                  Item.Cursor := Flyology_TUI.Glyphs.Cluster_Last
                    (Value (Item), Item.Cursor + 1);
               end if;
            when others => null;
         end case;
      end if;
   end Update;

   procedure Visible_Range
     (Item         : Model;
      First        : out Natural;
      Cursor_Cell  : out Natural)
   is
      Current : constant Wide_Wide_String := Value (Item);
      Prefix_Width : Natural :=
        (if Item.Cursor = 0 then 0
         else Flyology_TUI.Glyphs.Width_Of
           (Current (Current'First .. Item.Cursor)));
      Pos : Natural := Current'First;
   begin
      First := Current'First;
      while Prefix_Width >= Item.Columns and then Pos <= Item.Cursor loop
         declare
            Last : constant Natural :=
              Flyology_TUI.Glyphs.Cluster_Last (Current, Pos);
            Removed : constant Natural :=
              Flyology_TUI.Glyphs.Width_Of (Current (Pos .. Last));
         begin
            Prefix_Width := Prefix_Width - Removed;
            Pos := Last + 1;
            First := Pos;
         end;
      end loop;
      Cursor_Cell := Prefix_Width;
   end Visible_Range;

   function Render
     (Item                   : Model;
      Appearance             : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Placeholder_Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Item.Columns, 1, Appearance);
      Current : constant Wide_Wide_String := Value (Item);
      First, Cursor_Cell : Natural;
   begin
      if Current'Length = 0 then
         Result.Write
           (0,
            0,
            Text.To_Wide_Wide_String (Item.Placeholder),
            Placeholder_Appearance);
      else
         Visible_Range (Item, First, Cursor_Cell);
         if First <= Current'Last then
            Result.Write
              (0, 0, Current (First .. Current'Last), Appearance);
         end if;
      end if;
      return Result;
   end Render;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Theme.Input, Theme.Placeholder));

   function Cursor_Column (Item : Model) return Natural is
      First, Result : Natural;
   begin
      if Item.Columns = 0 then
         return 0;
      end if;
      Visible_Range (Item, First, Result);
      return Natural'Min (Result, Item.Columns - 1);
   end Cursor_Column;

end Flyology_TUI.Components.Text_Inputs;
