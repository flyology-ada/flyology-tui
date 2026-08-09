with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Breadcrumbs is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   Separator_Width : constant Natural := 3;

   function Symbol (Code : Natural) return Wide_Wide_String is
     (Wide_Wide_String'(1 => Wide_Wide_Character'Val (Code)));

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal    => Theme.Primary,
      Active    => Theme.Selected,
      Focused   => Theme.Focused,
      Separator => Theme.Border,
      Muted     => Theme.Muted);

   procedure Validate (Values : Item_Array) is
   begin
      if Values'Length > Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      for Left in Values'Range loop
         for Right in Values'Range loop
            if Right > Left
              and then Id_Of (Values (Left)) = Id_Of (Values (Right))
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;
   end Validate;

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));
   function Is_Empty (Item : Model) return Boolean is (Item.Values.Is_Empty);
   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Find (Item : Model; Id : Id_Type) return Natural is
   begin
      if not Item.Values.Is_Empty then
         for Position in 0 .. Natural (Item.Values.Length) - 1 loop
            if Id_Of (Item.Values.Element (Position)) = Id then
               return Position + 1;
            end if;
         end loop;
      end if;
      return 0;
   end Find;

   procedure Set_Items (Item : in out Model; Values : Item_Array) is
      New_Values  : Item_Vectors.Vector;
      New_Active  : Natural := 0;
      New_Focused : Natural := 0;
   begin
      Validate (Values);
      for Value of Values loop
         New_Values.Append (Value);
         if Item.Active > 0
           and then Id_Of (Value) =
             Id_Of (Item.Values.Element (Item.Active - 1))
         then
            New_Active := Natural (New_Values.Length);
         end if;
         if Item.Focused > 0
           and then Id_Of (Value) =
             Id_Of (Item.Values.Element (Item.Focused - 1))
         then
            New_Focused := Natural (New_Values.Length);
         end if;
      end loop;
      Item.Values := New_Values;
      if New_Values.Is_Empty then
         Item.Active := 0;
         Item.Focused := 0;
      else
         Item.Active :=
           (if New_Active > 0
            then New_Active else Natural (New_Values.Length));
         Item.Focused :=
           (if New_Focused > 0 then New_Focused else Item.Active);
      end if;
   end Set_Items;

   function Create
     (Values        : Item_Array;
      Maximum_Width : Natural := Natural'Last;
      Enabled       : Boolean := True) return Model
   is
      Result : Model :=
        (Max_Width => Maximum_Width, Enabled => Enabled, others => <>);
   begin
      Set_Items (Result, Values);
      return Result;
   end Create;

   procedure Set_Active (Item : in out Model; Id : Id_Type) is
      Position : constant Natural := Find (Item, Id);
   begin
      if Position = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Active := Position;
      Item.Focused := Position;
   end Set_Active;

   procedure Set_Maximum_Width (Item : in out Model; Width : Natural) is
   begin
      Item.Max_Width := Width;
   end Set_Maximum_Width;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
   end Set_Enabled;

   function Natural_Width (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      if Item.Values.Is_Empty then
         return 0;
      end if;
      for Position in 0 .. Length (Item) - 1 loop
         if Position > 0 then
            if Result > Natural'Last - Separator_Width then
               return Natural'Last;
            end if;
            Result := Result + Separator_Width;
         end if;
         declare
            Label_Width : constant Natural :=
              Flyology_TUI.Glyphs.Width_Of
                (Label (Item.Values.Element (Position)));
         begin
            if Label_Width > Natural'Last - Result then
               return Natural'Last;
            end if;
            Result := Result + Label_Width;
         end;
      end loop;
      return Result;
   end Natural_Width;

   function Width (Item : Model) return Natural is
     (Natural'Min (Natural_Width (Item), Item.Max_Width));

   function Active_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Active - 1)));
   function Focused_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Focused - 1)));

   procedure Window
     (Item : Model; First, Last : out Natural)
   is
      Used : Natural := 0;
      Candidate : Natural;
   begin
      if Item.Values.Is_Empty or else Width (Item) = 0 then
         First := 0;
         Last := 0;
         return;
      elsif Natural_Width (Item) <= Item.Max_Width then
         First := 1;
         Last := Length (Item);
         return;
      end if;

      First := Item.Focused;
      Last := First;
      Used := (if First > 1 then 2 else 0);
      declare
         Label_Width : constant Natural :=
           Flyology_TUI.Glyphs.Width_Of
             (Label (Item.Values.Element (First - 1)));
      begin
         if Label_Width > Natural'Last - Used then
            Used := Natural'Last;
         else
            Used := Used + Label_Width;
         end if;
      end;
      Candidate := First;
      while Candidate < Length (Item) loop
         Candidate := Candidate + 1;
         declare
            Label_Width : constant Natural :=
              Flyology_TUI.Glyphs.Width_Of
                (Label (Item.Values.Element (Candidate - 1)));
            Added : constant Natural :=
              (if Label_Width > Natural'Last - Separator_Width
               then Natural'Last else Separator_Width + Label_Width);
            Right_Marker : constant Natural :=
              (if Candidate < Length (Item) then 2 else 0);
         begin
            exit when Used > Item.Max_Width
              or else Added > Item.Max_Width - Used
              or else Right_Marker > Item.Max_Width - Used - Added;
            Used := Used + Added;
            Last := Candidate;
         end;
      end loop;
   end Window;

   function Region_By_Position
     (Item : Model; Position : Positive) return Flyology_TUI.Geometry.Rectangle
   is
      First, Last : Natural;
      X : Natural := 0;
   begin
      Window (Item, First, Last);
      if First = 0 or else Position < First or else Position > Last then
         return (X => 0, Y => 0, Width => 0, Height => 0);
      end if;
      if First > 1 then
         X := 2;
      end if;
      for Candidate in First .. Position - 1 loop
         X := X + Flyology_TUI.Glyphs.Width_Of
           (Label (Item.Values.Element (Candidate - 1)));
         X := X + Separator_Width;
      end loop;
      return
        (X => Integer (X), Y => 0,
         Width => Natural'Min
           (Flyology_TUI.Glyphs.Width_Of
              (Label (Item.Values.Element (Position - 1))),
            (if X < Width (Item) then Width (Item) - X else 0)),
         Height => (if X < Width (Item) then 1 else 0));
   end Region_By_Position;

   function Is_Visible (Item : Model; Id : Id_Type) return Boolean is
      Position : constant Natural := Find (Item, Id);
   begin
      return Position > 0
        and then Region_By_Position (Item, Position).Width > 0;
   end Is_Visible;

   function Item_Region
     (Item : Model; Id : Id_Type) return Flyology_TUI.Geometry.Rectangle
   is
      Position : constant Natural := Find (Item, Id);
   begin
      if Position = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      return Region_By_Position (Item, Position);
   end Item_Region;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Before : constant Natural := Item.Focused;
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Left_Key =>
            Item.Focused := Natural'Max (1, Item.Focused - 1);
         when Flyology_TUI.Events.Arrow_Right_Key =>
            Item.Focused := Natural'Min (Length (Item), Item.Focused + 1);
         when Flyology_TUI.Events.Home_Key => Item.Focused := 1;
         when Flyology_TUI.Events.End_Key => Item.Focused := Length (Item);
         when Flyology_TUI.Events.Enter_Key =>
            declare
               Changed : constant Boolean := Item.Active /= Item.Focused;
            begin
               Item.Active := Item.Focused;
               return
                 (Handled => True, Activated => True, Changed => Changed,
                  others => <>);
            end;
         when others =>
            return Flyology_TUI.Components.Interactions.Ignored;
      end case;
      return
        (Handled => True, Changed => Before /= Item.Focused, others => <>);
   end Handle;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
   begin
      if not Item.Enabled
        or else Event.Action /= Flyology_TUI.Events.Mouse_Click
        or else Event.Button /= Flyology_TUI.Events.Left_Button
        or else Event.X < 0 or else Event.Y /= 0
        or else Event.X >= Integer (Width (Item))
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      for Position in 1 .. Length (Item) loop
         if Flyology_TUI.Geometry.Contains
           (Region_By_Position (Item, Position), Event.X, Event.Y)
         then
            declare
               Changed : constant Boolean := Item.Active /= Position;
            begin
               Item.Active := Position;
               Item.Focused := Position;
               return
                 (Handled => True, Activated => True, Changed => Changed,
                  Focus_Requested => True, others => <>);
            end;
         end if;
      end loop;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event);
      pragma Unreferenced (Discard);
   begin null; end Update;

   function Render
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create
          (Width (Item), (if Item.Values.Is_Empty then 0 else 1));
      First, Last : Natural;
      X : Natural := 0;
   begin
      Window (Item, First, Last);
      if First = 0 then
         return Result;
      end if;
      if First > 1 then
         Result.Write (0, 0, Symbol (16#2026#) & " ", Look.Separator);
         X := 2;
      end if;
      for Position in First .. Last loop
         if Position > First then
            Result.Write (X, 0, " / ", Look.Separator);
            X := X + Separator_Width;
         end if;
         declare
            Style : constant Flyology_TUI.Styles.Style :=
              (if not Item.Enabled then Look.Muted
               elsif Has_Focus and then Position = Item.Focused
               then Look.Focused
               elsif Position = Item.Active then Look.Active else Look.Normal);
         begin
            Result.Write
              (X, 0, Label (Item.Values.Element (Position - 1)), Style);
            X := X + Flyology_TUI.Glyphs.Width_Of
              (Label (Item.Values.Element (Position - 1)));
         end;
      end loop;
      if Last < Length (Item) and then Width (Item) >= 2 then
         Result.Write
           (Width (Item) - 2, 0, " " & Symbol (16#2026#), Look.Separator);
      end if;
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Breadcrumbs;
