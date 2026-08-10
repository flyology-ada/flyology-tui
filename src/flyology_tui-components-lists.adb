package body Flyology_TUI.Components.Lists is
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;

   procedure Check_Size (Width, Height : Natural) is
   begin
      if Width /= 0 and then Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error with
           "list dimensions exceed addressable cell capacity";
      end if;
   end Check_Size;

   function Create (Width, Height : Positive) return Model is
   begin
      Check_Size (Width, Height);
      return
        (Values   => Item_Vectors.Empty_Vector,
         Selected => 0,
         Offset   => 0,
         Columns  => Width,
         Rows     => Height);
   end Create;

   procedure Keep_Visible (Item : in out Model) is
   begin
      if Item.Rows = 0 then
         Item.Offset := Item.Selected;
      elsif Item.Selected < Item.Offset then
         Item.Offset := Item.Selected;
      elsif Item.Selected - Item.Offset >= Item.Rows then
         Item.Offset := Item.Selected - Item.Rows + 1;
      end if;
   end Keep_Visible;

   procedure Set_Size
     (Item : in out Model;
      Width, Height : Natural)
   is
   begin
      Check_Size (Width, Height);
      Item.Columns := Width;
      Item.Rows := Height;
      Keep_Visible (Item);
   end Set_Size;

   function Width (Item : Model) return Natural is (Item.Columns);
   function Height (Item : Model) return Natural is (Item.Rows);

   procedure Set_Items (Item : in out Model; Values : Item_Array) is
   begin
      Item.Values.Clear;
      for Value of Values loop
         Item.Values.Append (Value);
      end loop;
      Item.Selected := 0;
      Item.Offset := 0;
   end Set_Items;

   procedure Move (Item : in out Model; Amount : Integer) is
      Last : Natural;
   begin
      if Item.Values.Is_Empty then
         return;
      end if;
      Last := Natural (Item.Values.Length) - 1;
      if Amount < 0 then
         if Amount = Integer'First
           or else Natural (-Amount) >= Item.Selected
         then
            Item.Selected := 0;
         else
            Item.Selected := Item.Selected - Natural (-Amount);
         end if;
      elsif Amount > 0 then
         if Natural (Amount) >= Last - Item.Selected then
            Item.Selected := Last;
         else
            Item.Selected := Item.Selected + Natural (Amount);
         end if;
      end if;
      Keep_Visible (Item);
   end Move;

   function Safe_Negate (Value : Integer) return Integer is
     (if Value = Integer'First then Integer'Last else -Value);

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      if Event.Kind = Flyology_TUI.Events.Mouse_Input then
         if Event.Mouse.X >= Item.Columns or else Event.Mouse.Y >= Item.Rows
         then
            return;
         elsif Event.Mouse.Action = Flyology_TUI.Events.Mouse_Click
           and then Event.Mouse.Button = Flyology_TUI.Events.Left_Button
         then
            declare
               Index : Natural;
            begin
               if Event.Mouse.Y > Natural'Last - Item.Offset then
                  return;
               end if;
               Index := Item.Offset + Event.Mouse.Y;
               if Index < Natural (Item.Values.Length) then
                  Item.Selected := Index;
                  Keep_Visible (Item);
               end if;
            end;
         elsif Event.Mouse.Action = Flyology_TUI.Events.Mouse_Wheel
           and then Event.Mouse.Wheel_Y /= 0
         then
            Move (Item, Safe_Negate (Event.Mouse.Wheel_Y));
         end if;
         return;
      elsif Event.Kind /= Flyology_TUI.Events.Key_Press then
         return;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key => Move (Item, -1);
         when Flyology_TUI.Events.Arrow_Down_Key => Move (Item, 1);
         when Flyology_TUI.Events.Page_Up_Key => Move (Item, -Item.Rows);
         when Flyology_TUI.Events.Page_Down_Key => Move (Item, Item.Rows);
         when Flyology_TUI.Events.Home_Key =>
            Item.Selected := 0;
            Keep_Visible (Item);
         when Flyology_TUI.Events.End_Key =>
            if not Item.Values.Is_Empty then
               Item.Selected := Natural (Item.Values.Length) - 1;
               Keep_Visible (Item);
            end if;
         when Flyology_TUI.Events.Text_Key =>
            declare
               Key : constant Wide_Wide_String :=
                 Text.To_Wide_Wide_String (Event.Key.Value);
            begin
               if Key = "j" then
                  Move (Item, 1);
               elsif Key = "k" then
                  Move (Item, -1);
               end if;
            end;
         when others => null;
      end case;
   end Update;

   function Is_Empty (Item : Model) return Boolean is
     (Item.Values.Is_Empty);

   function Selected_Index (Item : Model) return Natural is
     (if Item.Values.Is_Empty then 0 else Item.Selected);

   function Selected_Item (Item : Model) return Item_Type is
     (Item.Values.Element (Item.Selected));

   function Render
     (Item                : Model;
      Appearance          : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Selected_Appearance : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Marker : constant Wide_Wide_String :=
        (1 => Wide_Wide_Character'Val (16#203A#), 2 => ' ');
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Item.Columns, Item.Rows, Appearance);
   begin
      if Item.Columns = 0 or else Item.Rows = 0 then
         return Result;
      end if;
      for Row in 0 .. Item.Rows - 1 loop
         declare
            Index : constant Natural := Item.Offset + Row;
         begin
            exit when Index >= Natural (Item.Values.Length);
            if Index = Item.Selected then
               Result.Write
                 (0,
                  Row,
                  Marker & Label (Item.Values.Element (Index)),
                  Selected_Appearance);
            else
               Result.Write
                 (0,
                  Row,
                  "  " & Label (Item.Values.Element (Index)),
                  Appearance);
            end if;
         end;
      end loop;
      return Result;
   end Render;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface
   is (Render (Item, Theme.Muted, Theme.Selected));

end Flyology_TUI.Components.Lists;
