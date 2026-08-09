package body Flyology_TUI.Components.Lists is
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function Create (Width, Height : Positive) return Model is
     (Values   => Item_Vectors.Empty_Vector,
      Selected => 0,
      Offset   => 0,
      Columns  => Width,
      Rows     => Height);

   procedure Keep_Visible (Item : in out Model) is
   begin
      if Item.Selected < Item.Offset then
         Item.Offset := Item.Selected;
      elsif Item.Selected >= Item.Offset + Item.Rows then
         Item.Offset := Item.Selected - Item.Rows + 1;
      end if;
   end Keep_Visible;

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
      Last : constant Integer := Integer (Item.Values.Length) - 1;
   begin
      if Item.Values.Is_Empty then
         return;
      end if;
      Item.Selected := Natural
        (Integer'Max
           (0, Integer'Min (Last, Integer (Item.Selected) + Amount)));
      Keep_Visible (Item);
   end Move;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      if Event.Kind /= Flyology_TUI.Events.Key_Press then
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
        Flyology_TUI.Surfaces.Create (Item.Columns, Item.Rows);
   begin
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

end Flyology_TUI.Components.Lists;
