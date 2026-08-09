with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Forms is
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function Create
     (Fields      : Field_Array;
      Input_Width : Positive := 30) return Model
   is
      Result : Model;
   begin
      for Definition of Fields loop
         declare
            Input : Flyology_TUI.Components.Text_Inputs.Model :=
              Flyology_TUI.Components.Text_Inputs.Create
                (Input_Width,
                 Text.To_Wide_Wide_String (Definition.Placeholder));
         begin
            Input.Set_Value (Text.To_Wide_Wide_String (Definition.Initial));
            Result.Fields.Append
              ((Label => Definition.Label, Input => Input));
         end;
      end loop;
      if not Result.Fields.Is_Empty then
         Result.Fields.Reference (0).Input.Focus;
      end if;
      return Result;
   end Create;

   procedure Set_Active (Item : in out Model; Index : Natural) is
   begin
      if Item.Fields.Is_Empty then
         return;
      end if;
      Item.Fields.Reference (Item.Active).Input.Blur;
      Item.Active := Natural'Min (Index, Natural (Item.Fields.Length) - 1);
      Item.Fields.Reference (Item.Active).Input.Focus;
   end Set_Active;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event) is
   begin
      if Item.Fields.Is_Empty or else Item.Was_Submitted
        or else Item.Was_Cancelled
      then
         return;
      end if;
      if Event.Kind = Flyology_TUI.Events.Key_Press then
         case Event.Key.Kind is
            when Flyology_TUI.Events.Enter_Key =>
               if Item.Active + 1 < Natural (Item.Fields.Length) then
                  Set_Active (Item, Item.Active + 1);
               else
                  Item.Was_Submitted := True;
               end if;
               return;
            when Flyology_TUI.Events.Tab_Key =>
               if Event.Key.Modified.Shift then
                  Set_Active
                    (Item, (if Item.Active = 0 then 0 else Item.Active - 1));
               else
                  Set_Active
                    (Item,
                     Natural'Min
                       (Item.Active + 1, Natural (Item.Fields.Length) - 1));
               end if;
               return;
            when Flyology_TUI.Events.Escape_Key =>
               Item.Was_Cancelled := True;
               return;
            when others => null;
         end case;
      end if;
      Item.Fields.Reference (Item.Active).Input.Update (Event);
   end Update;

   function Submitted (Item : Model) return Boolean is (Item.Was_Submitted);
   function Cancelled (Item : Model) return Boolean is (Item.Was_Cancelled);

   procedure Reset_Status (Item : in out Model) is
   begin
      Item.Was_Submitted := False;
      Item.Was_Cancelled := False;
   end Reset_Status;

   function Field_Count (Item : Model) return Natural is
     (Natural (Item.Fields.Length));

   function Field_Value (Item : Model; Index : Positive)
      return Wide_Wide_String
   is (Item.Fields.Element (Index - 1).Input.Value);

   function Render
     (Item                : Model;
      Label_Appearance    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Input_Appearance    : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
      Focused_Appearance  : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default)
      return Flyology_TUI.Surfaces.Surface
   is
      Label_Width : Natural := 0;
   begin
      for Value of Item.Fields loop
         Label_Width := Natural'Max
           (Label_Width,
            Flyology_TUI.Glyphs.Width_Of
              (Text.To_Wide_Wide_String (Value.Label)));
      end loop;
      if Item.Fields.Is_Empty then
         return Flyology_TUI.Surfaces.Create (0, 0);
      end if;
      declare
         Input_Width : constant Natural :=
           Item.Fields.First_Element.Input.Render.Width;
         Result : Flyology_TUI.Surfaces.Surface :=
           Flyology_TUI.Surfaces.Create
             (Label_Width + 2 + Input_Width,
              Natural (Item.Fields.Length));
      begin
         for Index in Item.Fields.First_Index .. Item.Fields.Last_Index loop
            declare
               Value : constant Field := Item.Fields.Element (Index);
               Style : constant Flyology_TUI.Styles.Style :=
                 (if Index = Item.Active
                  then Focused_Appearance
                  else Input_Appearance);
            begin
               Result.Write
                 (0,
                  Index,
                  Text.To_Wide_Wide_String (Value.Label),
                  Label_Appearance);
               Result.Overlay
                 (Value.Input.Render (Style, Style), Label_Width + 2, Index);
            end;
         end loop;
         return Result;
      end;
   end Render;

end Flyology_TUI.Components.Forms;
