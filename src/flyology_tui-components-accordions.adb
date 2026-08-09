with Ada.Strings.Wide_Wide_Unbounded;

package body Flyology_TUI.Components.Accordions is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;

   function Symbol (Code : Natural) return Wide_Wide_String is
     (Wide_Wide_String'(1 => Wide_Wide_Character'Val (Code)));

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Header          => Theme.Primary,
      Expanded_Header => Theme.Selected,
      Focused_Header  => Theme.Focused,
      Disabled_Header => Theme.Muted,
      Content         => Theme.Primary);

   procedure Validate (Sections : Section_Array) is
   begin
      if Sections'Length > Capacity then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      for Left in Sections'Range loop
         for Right in Sections'Range loop
            if Right > Left
              and then Id_Of (Sections (Left)) = Id_Of (Sections (Right))
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;
   end Validate;

   function Find
     (Values : Section_Vectors.Vector;
      Id     : Id_Type) return Natural
   is
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

   function First_Enabled
     (Values : Boolean_Vectors.Vector) return Natural
   is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Values.Element (Index) then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end First_Enabled;

   function Next_Enabled
     (Values : Boolean_Vectors.Vector;
      From   : Natural;
      Step   : Integer) return Natural
   is
      Cursor : Integer := Integer (From) + Step;
      Last   : constant Integer := Integer (Values.Length);
   begin
      while Cursor >= 1 and then Cursor <= Last loop
         if Values.Element (Natural (Cursor) - 1) then
            return Natural (Cursor);
         end if;
         Cursor := Cursor + Step;
      end loop;
      return From;
   end Next_Enabled;

   function Last_Enabled
     (Values : Boolean_Vectors.Vector) return Natural
   is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in reverse 0 .. Natural (Values.Length) - 1 loop
         if Values.Element (Index) then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Last_Enabled;

   procedure Set_Sections
     (Item     : in out Model;
      Sections : Section_Array)
   is
      New_Sections : Section_Vectors.Vector;
      New_Expanded : Boolean_Vectors.Vector;
      New_Enabled  : Boolean_Vectors.Vector;
      New_Focused  : Natural := 0;
      Old_Index    : Natural;
   begin
      Validate (Sections);
      for Section of Sections loop
         New_Sections.Append (Section);
         Old_Index := Find (Item.Sections, Id_Of (Section));
         if Old_Index = 0 then
            New_Expanded.Append (False);
            New_Enabled.Append (True);
         else
            New_Expanded.Append (Item.Expanded.Element (Old_Index - 1));
            New_Enabled.Append (Item.Enabled.Element (Old_Index - 1));
            if Item.Focused = Old_Index then
               New_Focused := Natural (New_Sections.Length);
            end if;
         end if;
      end loop;

      if New_Focused > 0
        and then not New_Enabled.Element (New_Focused - 1)
      then
         New_Focused := 0;
      end if;
      if New_Focused = 0 then
         New_Focused := First_Enabled (New_Enabled);
      end if;

      Item.Sections := New_Sections;
      Item.Expanded := New_Expanded;
      Item.Enabled := New_Enabled;
      Item.Focused := New_Focused;
      Item.Armed := 0;
      --  Capturing deliberately survives so the eventual release can unwind
      --  application capture ownership without activating replacement data.
   end Set_Sections;

   function Create
     (Sections : Section_Array;
      Mode     : Expansion_Mode := Single_Expansion) return Model
   is
      Result : Model;
   begin
      Result.Kind := Mode;
      Set_Sections (Result, Sections);
      return Result;
   end Create;

   function Length (Item : Model) return Natural is
     (Natural (Item.Sections.Length));

   function Is_Empty (Item : Model) return Boolean is
     (Item.Sections.Is_Empty);

   function Mode (Item : Model) return Expansion_Mode is (Item.Kind);

   function Contains (Item : Model; Id : Id_Type) return Boolean is
     (Find (Item.Sections, Id) > 0);

   function Is_Expanded (Item : Model; Id : Id_Type) return Boolean is
     (Item.Expanded.Element (Find (Item.Sections, Id) - 1));

   function Is_Section_Enabled
     (Item : Model;
      Id   : Id_Type) return Boolean is
     (Item.Enabled.Element (Find (Item.Sections, Id) - 1));

   procedure Set_Expanded
     (Item     : in out Model;
      Id       : Id_Type;
      Expanded : Boolean := True)
   is
      Index : constant Natural := Find (Item.Sections, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Armed := 0;
      if Expanded and then Item.Kind = Single_Expansion then
         for Position in 0 .. Natural (Item.Expanded.Length) - 1 loop
            Item.Expanded.Replace_Element (Position, False);
         end loop;
      end if;
      Item.Expanded.Replace_Element (Index - 1, Expanded);
   end Set_Expanded;

   procedure Toggle (Item : in out Model; Id : Id_Type) is
      Index : constant Natural := Find (Item.Sections, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Set_Expanded
        (Item, Id, not Item.Expanded.Element (Index - 1));
   end Toggle;

   procedure Collapse_All (Item : in out Model) is
   begin
      Item.Armed := 0;
      if not Item.Expanded.Is_Empty then
         for Index in 0 .. Natural (Item.Expanded.Length) - 1 loop
            Item.Expanded.Replace_Element (Index, False);
         end loop;
      end if;
   end Collapse_All;

   procedure Expand_All (Item : in out Model) is
   begin
      Item.Armed := 0;
      if not Item.Expanded.Is_Empty then
         for Index in 0 .. Natural (Item.Expanded.Length) - 1 loop
            Item.Expanded.Replace_Element (Index, True);
         end loop;
      end if;
   end Expand_All;

   procedure Set_Section_Enabled
     (Item    : in out Model;
      Id      : Id_Type;
      Enabled : Boolean := True)
   is
      Index : constant Natural := Find (Item.Sections, Id);
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Item.Enabled.Replace_Element (Index - 1, Enabled);
      if not Enabled and then Item.Armed = Index then
         Item.Armed := 0;
      end if;
      if not Enabled and then Item.Focused = Index then
         Item.Focused := Next_Enabled (Item.Enabled, Index, 1);
         if Item.Focused = Index then
            Item.Focused := Next_Enabled (Item.Enabled, Index, -1);
         end if;
         if Item.Focused = Index then
            Item.Focused := 0;
         end if;
      elsif Enabled and then Item.Focused = 0 then
         Item.Focused := Index;
      end if;
   end Set_Section_Enabled;

   function Has_Focused_Section (Item : Model) return Boolean is
     (Item.Focused > 0);

   function Focused_Id (Item : Model) return Id_Type is
     (Id_Of (Item.Sections.Element (Item.Focused - 1)));

   function Expanded_Count (Item : Model) return Natural is
      Result : Natural := 0;
   begin
      for Value of Item.Expanded loop
         if Value then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Expanded_Count;

   function Find_Body
     (Bodies : Body_Array;
      Id     : Id_Type) return Natural
   is
   begin
      for Index in Bodies'Range loop
         if Bodies (Index).Id = Id then
            return Natural (Index);
         end if;
      end loop;
      return 0;
   end Find_Body;

   procedure Validate_Bodies
     (Item   : Model;
      Bodies : Body_Array)
   is
   begin
      if Bodies'Length /= Expanded_Count (Item) then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      for Left in Bodies'Range loop
         declare
            Section_Index : constant Natural :=
              Find (Item.Sections, Bodies (Left).Id);
         begin
            if Section_Index = 0
              or else not Item.Expanded.Element (Section_Index - 1)
            then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end;
         for Right in Bodies'Range loop
            if Right > Left and then Bodies (Left).Id = Bodies (Right).Id then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end loop;
      for Index in 1 .. Length (Item) loop
         if Item.Expanded.Element (Index - 1)
           and then Find_Body
             (Bodies, Id_Of (Item.Sections.Element (Index - 1))) = 0
         then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
      end loop;
   end Validate_Bodies;

   function Presentation_Index
     (Item : Presentation;
      Id   : Id_Type) return Natural
   is
   begin
      if Item.Ids.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Item.Ids.Length) - 1 loop
         if Item.Ids.Element (Index) = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Presentation_Index;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation
   is
      Result : Presentation;
      Total_Height : Natural := 0;
      Maximum_Coordinate : constant Natural := Natural (Integer'Last);
   begin
      Validate_Bodies (Item, Bodies);
      for Index in 1 .. Length (Item) loop
         if Total_Height = Maximum_Coordinate then
            raise Flyology_TUI.Components.Capacity_Error;
         end if;
         Total_Height := Total_Height + 1;
         if Item.Expanded.Element (Index - 1) then
            declare
               Body_Index : constant Natural := Find_Body
                 (Bodies, Id_Of (Item.Sections.Element (Index - 1)));
               Body_Height : constant Natural :=
                 Bodies (Positive (Body_Index)).Content.Height;
            begin
               if Body_Height > Maximum_Coordinate - Total_Height then
                  raise Flyology_TUI.Components.Capacity_Error;
               end if;
               Total_Height := Total_Height + Body_Height;
            end;
         end if;
      end loop;
      if Width /= 0 and then Total_Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;

      Result.Frame_Value :=
        Flyology_TUI.Surfaces.Create (Width, Total_Height);
      declare
         Y : Natural := 0;
      begin
         for Index in 1 .. Length (Item) loop
            declare
               Id : constant Id_Type :=
                 Id_Of (Item.Sections.Element (Index - 1));
               Expanded : constant Boolean :=
                 Item.Expanded.Element (Index - 1);
               Enabled : constant Boolean :=
                 Item.Enabled.Element (Index - 1);
               Header_Style : constant Flyology_TUI.Styles.Style :=
                 (if not Enabled then Look.Disabled_Header
                  elsif Has_Focus and then Item.Focused = Index
                  then Look.Focused_Header
                  elsif Expanded then Look.Expanded_Header
                  else Look.Header);
               Header : Flyology_TUI.Surfaces.Surface :=
                 Flyology_TUI.Surfaces.Create (Width, 1, Header_Style);
            begin
               Header.Write
                 (0, 0,
                  (if Expanded
                   then Symbol (16#25BE#) & " "
                   else Symbol (16#25B8#) & " ")
                    & Label (Item.Sections.Element (Index - 1)),
                  Header_Style);
               Result.Frame_Value.Overlay_Clipped
                 (Header, 0, Integer (Y));
               Result.Ids.Append (Id);
               Result.Header_Regions.Append
                 (Flyology_TUI.Geometry.Rectangle'
                    (X => 0, Y => Integer (Y), Width => Width, Height => 1));
               Y := Y + 1;

               if Expanded then
                  declare
                     Body_Index : constant Natural := Find_Body (Bodies, Id);
                     Content : constant Flyology_TUI.Surfaces.Surface :=
                       Bodies (Positive (Body_Index)).Content;
                     Body_Canvas : Flyology_TUI.Surfaces.Surface :=
                       Flyology_TUI.Surfaces.Create
                         (Width, Content.Height, Look.Content);
                  begin
                     Body_Canvas.Overlay_Clipped (Content, 0, 0);
                     Result.Frame_Value.Overlay_Clipped
                       (Body_Canvas, 0, Integer (Y));
                     Result.Body_Regions.Append
                       (Flyology_TUI.Geometry.Rectangle'
                          (X      => 0,
                           Y      => Integer (Y),
                           Width  => Width,
                           Height => Content.Height));
                     Result.Body_Visible.Append (True);
                     Y := Y + Content.Height;
                  end;
               else
                  Result.Body_Regions.Append
                    (Flyology_TUI.Geometry.Rectangle'(others => <>));
                  Result.Body_Visible.Append (False);
               end if;
            end;
         end loop;
      end;
      return Result;
   end Present;

   function Present
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation is
     (Present (Item, Bodies, Width, From_Theme (Theme), Has_Focus));

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface is
     (Item.Frame_Value);

   function Has_Section
     (Item : Presentation;
      Id   : Id_Type) return Boolean is
     (Presentation_Index (Item, Id) > 0);

   function Header_Region
     (Item : Presentation;
      Id   : Id_Type) return Flyology_TUI.Geometry.Rectangle is
     (Item.Header_Regions.Element (Presentation_Index (Item, Id) - 1));

   function Has_Body_Region
     (Item : Presentation;
      Id   : Id_Type) return Boolean
   is
      Index : constant Natural := Presentation_Index (Item, Id);
   begin
      return Index > 0 and then Item.Body_Visible.Element (Index - 1);
   end Has_Body_Region;

   function Body_Region
     (Item : Presentation;
      Id   : Id_Type) return Flyology_TUI.Geometry.Rectangle is
     (Item.Body_Regions.Element (Presentation_Index (Item, Id) - 1));

   function Render
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Frame (Present (Item, Bodies, Width, Look, Has_Focus)));

   function Render
     (Item      : Model;
      Bodies    : Body_Array;
      Width     : Natural;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Frame (Present (Item, Bodies, Width, Theme, Has_Focus)));

   function Is_Activation_Key
     (Event : Flyology_TUI.Events.Terminal_Event) return Boolean is
     (Event.Key.Kind = Flyology_TUI.Events.Enter_Key
      or else
        (Event.Key.Kind = Flyology_TUI.Events.Text_Key
         and then Text.To_Wide_Wide_String (Event.Key.Value) = " "));

   function Change_Expansion
     (Item     : in out Model;
      Index    : Positive;
      Expanded : Boolean)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Was_Expanded : constant Boolean :=
        Item.Expanded.Element (Index - 1);
   begin
      if Was_Expanded = Expanded then
         return
           (Handled => True, others => <>);
      end if;
      Set_Expanded
        (Item, Id_Of (Item.Sections.Element (Index - 1)), Expanded);
      return
        (Handled   => True,
         Activated => True,
         Changed   => True,
         others    => <>);
   end Change_Expansion;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Prior : Natural;
   begin
      if Item.Focused = 0
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Flyology_TUI.Components.Interactions.Ignored;
      end if;
      case Event.Key.Kind is
         when Flyology_TUI.Events.Arrow_Up_Key =>
            Prior := Item.Focused;
            Item.Focused := Next_Enabled (Item.Enabled, Item.Focused, -1);
            return
              (Handled => True,
               Changed => Item.Focused /= Prior,
               others  => <>);
         when Flyology_TUI.Events.Arrow_Down_Key =>
            Prior := Item.Focused;
            Item.Focused := Next_Enabled (Item.Enabled, Item.Focused, 1);
            return
              (Handled => True,
               Changed => Item.Focused /= Prior,
               others  => <>);
         when Flyology_TUI.Events.Home_Key =>
            Prior := Item.Focused;
            Item.Focused := First_Enabled (Item.Enabled);
            return
              (Handled => True,
               Changed => Item.Focused /= Prior,
               others  => <>);
         when Flyology_TUI.Events.End_Key =>
            Prior := Item.Focused;
            Item.Focused := Last_Enabled (Item.Enabled);
            return
              (Handled => True,
               Changed => Item.Focused /= Prior,
               others  => <>);
         when Flyology_TUI.Events.Arrow_Left_Key =>
            return Change_Expansion
              (Item, Item.Focused, Expanded => False);
         when Flyology_TUI.Events.Arrow_Right_Key =>
            return Change_Expansion
              (Item, Item.Focused, Expanded => True);
         when others =>
            if Is_Activation_Key (Event) then
               return Change_Expansion
                 (Item,
                  Item.Focused,
                  not Item.Expanded.Element (Item.Focused - 1));
            end if;
      end case;
      return Flyology_TUI.Components.Interactions.Ignored;
   end Handle;

   function Header_Hit
     (Layout : Presentation;
      Event  : Flyology_TUI.Mouse.Local_Event) return Natural
   is
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Event.X, Y => Event.Y);
   begin
      if Layout.Header_Regions.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Layout.Header_Regions.Length) - 1 loop
         if Flyology_TUI.Geometry.Contains
           (Layout.Header_Regions.Element (Index), Point)
         then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Header_Hit;

   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Layout_Index : constant Natural := Header_Hit (Layout, Event);
      Index : Natural := 0;
      Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if Layout_Index > 0 then
         Index := Find
           (Item.Sections, Layout.Ids.Element (Layout_Index - 1));
      end if;
      if Event.Button /= Flyology_TUI.Events.Left_Button then
         return Result;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Click then
         if Index > 0 and then Item.Enabled.Element (Index - 1) then
            Result.Handled := True;
            Result.Focus_Requested := True;
            Result.Changed := Item.Focused /= Index;
            Result.Capture :=
              Flyology_TUI.Components.Interactions.Acquire_Capture;
            Item.Focused := Index;
            Item.Armed := Index;
            Item.Capturing := True;
         end if;
      elsif Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Item.Capturing
      then
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         if Item.Armed > 0
           and then Index = Item.Armed
           and then Item.Enabled.Element (Item.Armed - 1)
         then
            declare
               Changed : constant
                 Flyology_TUI.Components.Interactions.Update_Result :=
                   Change_Expansion
                     (Item,
                      Item.Armed,
                      not Item.Expanded.Element (Item.Armed - 1));
            begin
               Result.Activated := Changed.Activated;
               Result.Changed := Changed.Changed;
            end;
         end if;
         Item.Armed := 0;
         Item.Capturing := False;
      end if;
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

end Flyology_TUI.Components.Accordions;
