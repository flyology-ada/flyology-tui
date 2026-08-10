with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Tabs is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Normal   => Theme.Primary,
      Active   => Theme.Selected,
      Focused  => Theme.Focused,
      Disabled => Theme.Muted);

   function From_Palette
     (Palette : Flyology_TUI.Themes.Palette) return Appearance is
     (Normal   => Palette.Content,
      Active   => Palette.Button_Focused,
      Focused  => Palette.Interaction,
      Disabled => Palette.Disabled);

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

   function Find
     (Values : Item_Vectors.Vector;
      Id     : Id_Type) return Natural is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Id_Of (Values.Element (Index)) = Id then
            return Index + 1;
         end if;
      end loop;
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
      end loop;
      if not New_Values.Is_Empty then
         if Item.Active > 0 then
            New_Active := Find
              (New_Values, Id_Of (Item.Values.Element (Item.Active - 1)));
         end if;
         if New_Active = 0 then
            New_Active := 1;
         end if;
         if Item.Focused > 0 then
            New_Focused := Find
              (New_Values, Id_Of (Item.Values.Element (Item.Focused - 1)));
         end if;
         if New_Focused = 0 then
            New_Focused := New_Active;
         end if;
      end if;
      Item.Values := New_Values;
      Item.Active := New_Active;
      Item.Focused := New_Focused;
      Item.Armed := 0;
   end Set_Items;

   function Create
     (Values  : Item_Array;
      Enabled : Boolean := True) return Model
   is
      Result : Model;
   begin
      Result.Enabled := Enabled;
      Set_Items (Result, Values);
      return Result;
   end Create;

   procedure Activate (Item : in out Model; Id : Id_Type) is
      Index : constant Natural := Find (Item.Values, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Active := Index;
      Item.Focused := Index;
      Item.Armed := 0;
   end Activate;

   function Length (Item : Model) return Natural is
     (Natural (Item.Values.Length));
   function Is_Empty (Item : Model) return Boolean is (Item.Values.Is_Empty);
   function Active_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Values.Element (Item.Active - 1)));

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      Item.Enabled := Enabled;
      if not Enabled then
         Item.Armed := 0;
      end if;
   end Set_Enabled;
   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Tab_Width (Item : Model; Index : Positive) return Natural is
      Label_Columns : constant Natural :=
        Flyology_TUI.Glyphs.Width_Of
          (Label (Item.Values.Element (Index - 1)));
   begin
      if Label_Columns > Natural'Last - 2 then
         raise Flyology_TUI.Components.Capacity_Error with
           "tab label exceeds addressable width";
      end if;
      return Label_Columns + 2;
   end Tab_Width;

   function Width (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      for Index in 1 .. Length (Item) loop
         if Index > 1 then
            if Result = Natural'Last then
               raise Flyology_TUI.Components.Capacity_Error with
                 "tab bar exceeds addressable width";
            end if;
            Result := Result + 1;
         end if;
         declare
            Columns : constant Natural := Tab_Width (Item, Index);
         begin
            if Columns > Natural'Last - Result then
               raise Flyology_TUI.Components.Capacity_Error with
                 "tab bar exceeds addressable width";
            end if;
            Result := Result + Columns;
         end;
      end loop;
      return Result;
   end Width;

   function Presentation_Index
     (Item : Presentation; Id : Id_Type) return Natural
   is
   begin
      if Item.Ids.Is_Empty then
         return 0;
      end if;
      for Index in Item.Ids.First_Index .. Item.Ids.Last_Index loop
         if Item.Ids.Element (Index) = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Presentation_Index;

   function Present
     (Item      : Model;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation
   is
      Result : Presentation;
      Total : constant Natural := Tabs.Width (Item);
      Active_Start : Natural := 0;
      Active_Width : Natural := 0;
      View_Start : Natural := 0;
      View_End : Natural := 0;
      Start : Natural := 0;
   begin
      Result.Frame_Value := Flyology_TUI.Surfaces.Create (Width, 1);
      if Item.Values.Is_Empty or else Width = 0 then
         return Result;
      end if;

      for Index in 1 .. Length (Item) loop
         if Index = Item.Active then
            Active_Start := Start;
            Active_Width := Tab_Width (Item, Index);
            exit;
         end if;
         Start := Start + Tab_Width (Item, Index) + 1;
      end loop;
      if Active_Width > Width then
         View_Start := Active_Start;
      elsif Active_Start + Active_Width > Width then
         View_Start := Active_Start + Active_Width - Width;
      end if;
      View_End := View_Start + Natural'Min (Width, Total - View_Start);

      Start := 0;
      for Index in 1 .. Length (Item) loop
         declare
            Columns : constant Natural := Tab_Width (Item, Index);
            Finish : constant Natural := Start + Columns;
            Visible_First : constant Natural :=
              Natural'Max (Start, View_Start);
            Visible_Last : constant Natural := Natural'Min (Finish, View_End);
            Style : constant Flyology_TUI.Styles.Style :=
              (if not Item.Enabled then Look.Disabled
               elsif Item.Active = Index then Look.Active
               elsif Has_Focus and then Item.Focused = Index
               then Look.Focused
               else Look.Normal);
            Tab : Flyology_TUI.Surfaces.Surface :=
              Flyology_TUI.Surfaces.Create (Columns, 1);
         begin
            Tab.Write
              (0, 0,
               (if Item.Active = Index
                then "[" & Label (Item.Values.Element (Index - 1)) & "]"
                elsif Has_Focus and then Item.Focused = Index
                then ">" & Label (Item.Values.Element (Index - 1)) & " "
                else " " & Label (Item.Values.Element (Index - 1)) & " "),
               Style);
            Result.Frame_Value.Overlay_Clipped
              (Tab, Integer (Start) - Integer (View_Start), 0);
            if Visible_First < Visible_Last then
               Result.Ids.Append (Id_Of (Item.Values.Element (Index - 1)));
               Result.Regions.Append
                 (Flyology_TUI.Geometry.Rectangle'
                    (X      => Integer (Visible_First - View_Start),
                     Y      => 0,
                     Width  => Visible_Last - Visible_First,
                     Height => 1));
            end if;
            if Index < Length (Item)
              and then Finish >= View_Start
              and then Finish < View_End
            then
               Result.Frame_Value.Put
                 (Finish - View_Start, 0, " ", Look.Normal);
            end if;
            Start :=
              (if Index < Length (Item) then Finish + 1 else Finish);
         end;
      end loop;
      return Result;
   end Present;

   function Present
     (Item      : Model;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation
   is (Present (Item, Width, From_Theme (Theme), Has_Focus));

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface
   is (Item.Frame_Value);

   function Has_Tab
     (Item : Presentation; Id : Id_Type) return Boolean
   is (Presentation_Index (Item, Id) > 0);

   function Tab_Region
     (Item : Presentation;
      Id   : Id_Type) return Flyology_TUI.Geometry.Rectangle
   is (Item.Regions.Element (Presentation_Index (Item, Id) - 1));

   procedure Move_Focus (Item : in out Model; Amount : Integer) is
      Last : constant Integer := Integer (Item.Values.Length);
   begin
      Item.Focused := Natural
        (Integer'Max (1, Integer'Min (Last, Integer (Item.Focused) + Amount)));
   end Move_Focus;

   function Choose_Focused
     (Item : in out Model)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Changed : constant Boolean := Item.Active /= Item.Focused;
   begin
      Item.Active := Item.Focused;
      return
        (Handled => True, Activated => True, Changed => Changed, others => <>);
   end Choose_Focused;

   function Commit_Navigation
     (Item         : in out Model;
      Prior_Focus  : Natural;
      Prior_Active : Natural)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Focus_Changed : constant Boolean := Item.Focused /= Prior_Focus;
      Identity_Changed : constant Boolean := Item.Focused /= Prior_Active;
   begin
      Item.Active := Item.Focused;
      return
        (Handled   => True,
         Activated => Identity_Changed,
         Changed   => Focus_Changed or else Identity_Changed,
         others    => <>);
   end Commit_Navigation;

   function Is_Activation_Key
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean is
   begin
      return Event.Key.Kind = Flyology_TUI.Events.Enter_Key
        or else
          (Event.Key.Kind = Flyology_TUI.Events.Text_Key
           and then Text.To_Wide_Wide_String (Event.Key.Value) = " ");
   end Is_Activation_Key;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Prior_Focus  : Natural;
      Prior_Active : Natural;
   begin
      if not Item.Enabled or else Item.Values.Is_Empty
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Left_Key =>
            Prior_Focus := Item.Focused;
            Prior_Active := Item.Active;
            Move_Focus (Item, -1);
            return Commit_Navigation (Item, Prior_Focus, Prior_Active);
         when Flyology_TUI.Events.Arrow_Right_Key =>
            Prior_Focus := Item.Focused;
            Prior_Active := Item.Active;
            Move_Focus (Item, 1);
            return Commit_Navigation (Item, Prior_Focus, Prior_Active);
         when Flyology_TUI.Events.Home_Key =>
            Prior_Focus := Item.Focused;
            Prior_Active := Item.Active;
            Item.Focused := 1;
            return Commit_Navigation (Item, Prior_Focus, Prior_Active);
         when Flyology_TUI.Events.End_Key =>
            Prior_Focus := Item.Focused;
            Prior_Active := Item.Active;
            Item.Focused := Natural (Item.Values.Length);
            return Commit_Navigation (Item, Prior_Focus, Prior_Active);
         when others =>
            if Is_Activation_Key (Event) then
               return Choose_Focused (Item);
            end if;
      end case;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   function Hit_Tab
     (Item : Model; Event : Flyology_TUI.Mouse.Local_Event) return Natural
   is
      Full_Width : constant Natural := Width (Item);
      pragma Unreferenced (Full_Width);
      Start : Natural := 0;
   begin
      if Event.X < 0 or else Event.Y /= 0 then
         return 0;
      end if;
      for Index in 1 .. Length (Item) loop
         if Natural (Event.X) >= Start
           and then Natural (Event.X) < Start + Tab_Width (Item, Index)
         then
            return Index;
         end if;
         Start := Start + Tab_Width (Item, Index);
         if Index < Length (Item) then
            Start := Start + 1;
         end if;
      end loop;
      return 0;
   end Hit_Tab;

   function Handle_Hit
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event;
      Hit   : Natural)
      return Flyology_TUI.Components.Interactions.Update_Result;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Hit    : constant Natural := Hit_Tab (Item, Event);
   begin
      return Handle_Hit (Item, Event, Hit);
   end Handle;

   function Handle_Hit
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event;
      Hit   : Natural)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Focus_Changed : constant Boolean := Item.Focused /= Hit;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Event.Button /= Flyology_TUI.Events.Left_Button then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click then
         if Item.Enabled and then Hit > 0 then
            Item.Armed := Hit;
            Item.Capturing := True;
            Item.Focused := Hit;
            return
              (Handled         => True,
               Changed         => Focus_Changed,
               Focus_Requested => True,
               Capture         =>
                 Flyology_TUI.Components.Interactions.Acquire_Capture,
               others          => <>);
         end if;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Item.Capturing
      then
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         if Item.Enabled and then Item.Armed > 0 and then Hit = Item.Armed then
            Result.Changed := Item.Active /= Hit;
            Item.Active := Hit;
            Item.Focused := Hit;
            Result.Activated := True;
         end if;
         Item.Armed := 0;
         Item.Capturing := False;
         return Result;
      end if;
      return Result;
   end Handle_Hit;

   function Hit_Tab
     (Layout : Presentation;
      Event  : Flyology_TUI.Mouse.Local_Event) return Natural
   is
      Point : constant Flyology_TUI.Geometry.Point := (Event.X, Event.Y);
   begin
      if Layout.Regions.Is_Empty then
         return 0;
      end if;
      for Index in Layout.Regions.First_Index .. Layout.Regions.Last_Index loop
         if Flyology_TUI.Geometry.Contains
           (Layout.Regions.Element (Index), Point)
         then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Hit_Tab;

   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Layout_Index : constant Natural := Hit_Tab (Layout, Event);
      Current_Index : constant Natural :=
        (if Layout_Index = 0 then 0
         else Find (Item.Values, Layout.Ids.Element (Layout_Index - 1)));
   begin
      return Handle_Hit (Item, Event, Current_Index);
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

   procedure Update
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
   is
      Discard : constant Flyology_TUI.Components.Interactions.Update_Result :=
        Handle (Item, Event, Layout);
      pragma Unreferenced (Discard);
   begin null; end Update;

   function Render
     (Item      : Model;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface
   is
      Result : Flyology_TUI.Surfaces.Surface :=
        Flyology_TUI.Surfaces.Create (Width (Item), 1);
      X : Natural := 0;
   begin
      for Index in 1 .. Length (Item) loop
         if Index > 1 then
            Result.Write (X, 0, " ", Look.Normal);
            X := X + 1;
         end if;
         declare
            Style : constant Flyology_TUI.Styles.Style :=
              (if not Item.Enabled then Look.Disabled
               elsif Item.Active = Index then Look.Active
               elsif Has_Focus and then Item.Focused = Index then Look.Focused
               else Look.Normal);
         begin
            Result.Write
              (X, 0,
               (if Item.Active = Index
                then "[" & Label (Item.Values.Element (Index - 1)) & "]"
                elsif Has_Focus and then Item.Focused = Index
                then ">" & Label (Item.Values.Element (Index - 1)) & " "
                else " " & Label (Item.Values.Element (Index - 1)) & " "),
               Style);
            X := X + Tab_Width (Item, Index);
         end;
      end loop;
      return Result;
   end Render;

   function Render
     (Item      : Model;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Render (Item, From_Theme (Theme), Has_Focus));

end Flyology_TUI.Components.Tabs;
