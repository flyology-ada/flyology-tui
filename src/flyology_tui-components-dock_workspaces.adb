with Ada.Strings.Wide_Wide_Unbounded;
package body Flyology_TUI.Components.Dock_Workspaces is
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Flyology_TUI.Components.Interactions.Capture_Action;
   use type Interfaces.Unsigned_64;

   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   function Chrome_Style
     (Value : Flyology_TUI.Styles.Style) return Flyology_TUI.Styles.Style
   is
      Result : Flyology_TUI.Styles.Style := Value;
   begin
      Result.Italic := False;
      Result.Underline := False;
      Result.Blink := False;
      Result.Strikethrough := False;
      return Result;
   end Chrome_Style;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance
   is
     (Workspace       => Theme.Primary,
      Dock            => Theme.Input,
      Header          => Chrome_Style (Theme.Border),
      Focused_Header  => Chrome_Style (Theme.Selected),
      Rail            => Chrome_Style (Theme.Border),
      Focused_Rail    => Chrome_Style (Theme.Selected),
      Action          => Theme.Focused,
      Drop_Target     => Theme.Success,
      Disabled        => Theme.Muted,
      Floating_Window => Flyology_TUI.Components.Windows.From_Theme (Theme));

   procedure Bump (Item : in out Model) is
   begin
      Item.Revision := Item.Revision + Revision_Number'(1);
   end Bump;

   procedure Validate_Cells (Width, Height : Natural) is
   begin
      if Width /= 0 and then Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error with
           "dock workspace exceeds addressable cell capacity";
      end if;
   end Validate_Cells;

   function Slot_Of (Item : Model; Id : Pane_Id) return Slot_Index is
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used and then Item.Panes (Index).Id = Id then
            return Index;
         end if;
      end loop;
      raise Flyology_TUI.Components.Structure_Error with
        "unknown dock pane ID";
   end Slot_Of;

   function Occupant
     (Item : Model; Value : Dock_Side; Except : Slot_Index)
      return Natural
   is
   begin
      for Index in Slot_Index loop
         if Index /= Except
           and then Item.Panes (Index).Used
           and then Item.Panes (Index).Place = Docked
           and then Item.Panes (Index).Dock = Value
         then
            return Natural (Index);
         end if;
      end loop;
      return 0;
   end Occupant;

   function Occupant (Item : Model; Value : Dock_Side) return Natural is
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used
           and then Item.Panes (Index).Place = Docked
           and then Item.Panes (Index).Dock = Value
         then
            return Natural (Index);
         end if;
      end loop;
      return 0;
   end Occupant;

   procedure Sync_Window_Focus (Item : in out Model) is
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used then
            if Item.Has_Focus
              and then Index = Item.Active
              and then Item.Panes (Index).Place = Floating
            then
               Item.Panes (Index).Window.Focus;
            else
               Item.Panes (Index).Window.Blur;
            end if;
         end if;
      end loop;
   end Sync_Window_Focus;

   function Create
     (Panes         : Pane_Definition_Array;
      Width, Height : Natural) return Model
   is
      Result : Model;
      Count  : Natural := 0;
   begin
      Validate_Cells (Width, Height);
      if Panes'Length > Maximum_Panes then
         raise Flyology_TUI.Components.Capacity_Error with
           "dock pane capacity exceeded";
      end if;

      for Position in Panes'Range loop
         if Position /= Panes'First then
            for Earlier in Panes'First .. Position - 1 loop
               if Panes (Earlier).Id = Panes (Position).Id then
                  raise Flyology_TUI.Components.Structure_Error with
                    "duplicate dock pane ID";
               end if;
               if not Panes (Earlier).Initially_Floating
                 and then not Panes (Position).Initially_Floating
                 and then Panes (Earlier).Side = Panes (Position).Side
               then
                  raise Flyology_TUI.Components.Structure_Error with
                    "multiple panes occupy one dock side";
               end if;
            end loop;
         end if;
         Count := Count + 1;
         declare
            Index : constant Slot_Index := Slot_Index (Count);
            Value : constant Pane_Definition := Panes (Position);
         begin
            Result.Panes (Index) :=
              (Used           => True,
               Id             => Value.Id,
               Place          =>
                 (if Value.Initially_Floating then Floating else Docked),
               Dock           => Value.Side,
               Dock_Extent    =>
                 Positive'Max (Value.Dock_Extent, Value.Minimum_Extent),
               Minimum_Extent => Value.Minimum_Extent,
               Collapsed      =>
                 Value.Initially_Collapsed and then Value.Collapsible,
               Floatable      => Value.Floatable,
               Collapsible    => Value.Collapsible,
               Window         => Flyology_TUI.Components.Windows.Create
                 (Value.Float_X, Value.Float_Y,
                  Value.Float_Width, Value.Float_Height,
                  Minimum_Width  => 8,
                  Minimum_Height => 4,
                  Closable       => False));
            Result.Panes (Index).Window.Constrain_To
              ((0, 0, Width, Height));
            if Value.Initially_Floating then
               Result.Top_Floating := Index;
            end if;
         end;
      end loop;
      Result.Columns := Width;
      Result.Rows := Height;
      Result.Count := Count;
      Result.Active := Slot_Index'First;
      Sync_Window_Focus (Result);
      return Result;
   end Create;

   procedure Resize
     (Item          : in out Model;
      Width, Height : Natural)
   is
   begin
      Validate_Cells (Width, Height);
      if Item.Columns = Width and then Item.Rows = Height then
         return;
      end if;
      Item.Columns := Width;
      Item.Rows := Height;
      for Index in Slot_Index loop
         if Item.Panes (Index).Used then
            Item.Panes (Index).Window.Constrain_To
              ((0, 0, Width, Height));
         end if;
      end loop;
      Item.Header_Drag := False;
      Item.Has_Drop_Target := False;
      Bump (Item);
   end Resize;

   function Width (Item : Model) return Natural is (Item.Columns);
   function Height (Item : Model) return Natural is (Item.Rows);
   function Bounds (Item : Model) return Flyology_TUI.Geometry.Rectangle is
     ((0, 0, Item.Columns, Item.Rows));
   function Pane_Count (Item : Model) return Natural is (Item.Count);

   function Has_Pane (Item : Model; Id : Pane_Id) return Boolean is
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used and then Item.Panes (Index).Id = Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Pane;

   function Placement
     (Item : Model; Id : Pane_Id) return Pane_Placement
   is (Item.Panes (Slot_Of (Item, Id)).Place);

   function Side (Item : Model; Id : Pane_Id) return Dock_Side is
     (Item.Panes (Slot_Of (Item, Id)).Dock);

   function Is_Collapsed (Item : Model; Id : Pane_Id) return Boolean is
     (Item.Panes (Slot_Of (Item, Id)).Collapsed);

   procedure Float_Index (Item : in out Model; Index : Slot_Index) is
   begin
      if Item.Panes (Index).Place = Docked
        and then Item.Panes (Index).Floatable
      then
         Item.Panes (Index).Place := Floating;
         Item.Panes (Index).Collapsed := False;
         Item.Active := Index;
         Item.Top_Floating := Index;
         if Item.Capturing and then Item.Captured = Index then
            Item.Header_Drag := False;
            Item.Has_Drop_Target := False;
         end if;
         Bump (Item);
         Sync_Window_Focus (Item);
      end if;
   end Float_Index;

   procedure Float_Pane (Item : in out Model; Id : Pane_Id) is
   begin
      Float_Index (Item, Slot_Of (Item, Id));
   end Float_Pane;

   procedure Dock_Index
     (Item : in out Model; Index : Slot_Index; To_Side : Dock_Side)
   is
   begin
      if Occupant (Item, To_Side, Index) /= 0 then
         raise Flyology_TUI.Components.Structure_Error with
           "dock side is already occupied";
      end if;
      if Item.Panes (Index).Place /= Docked
        or else Item.Panes (Index).Dock /= To_Side
      then
         Item.Panes (Index).Place := Docked;
         Item.Panes (Index).Dock := To_Side;
         Item.Panes (Index).Collapsed := False;
         Item.Active := Index;
         if Item.Capturing and then Item.Captured = Index then
            Item.Header_Drag := False;
            Item.Has_Drop_Target := False;
         end if;
         Bump (Item);
         Sync_Window_Focus (Item);
      end if;
   end Dock_Index;

   procedure Dock_Pane
     (Item : in out Model; Id : Pane_Id; To_Side : Dock_Side)
   is
   begin
      Dock_Index (Item, Slot_Of (Item, Id), To_Side);
   end Dock_Pane;

   procedure Toggle_Index (Item : in out Model; Index : Slot_Index) is
   begin
      if Item.Panes (Index).Place = Docked
        and then Item.Panes (Index).Collapsible
      then
         Item.Panes (Index).Collapsed := not Item.Panes (Index).Collapsed;
         Item.Active := Index;
         if Item.Capturing and then Item.Captured = Index then
            Item.Header_Drag := False;
            Item.Has_Drop_Target := False;
         end if;
         Bump (Item);
      end if;
   end Toggle_Index;

   procedure Toggle_Collapsed (Item : in out Model; Id : Pane_Id) is
   begin
      Toggle_Index (Item, Slot_Of (Item, Id));
   end Toggle_Collapsed;

   procedure Focus (Item : in out Model) is
   begin
      Item.Has_Focus := True;
      Sync_Window_Focus (Item);
   end Focus;

   procedure Blur (Item : in out Model) is
   begin
      Item.Has_Focus := False;
      Sync_Window_Focus (Item);
   end Blur;

   function Focused (Item : Model) return Boolean is (Item.Has_Focus);

   procedure Focus_Pane (Item : in out Model; Id : Pane_Id) is
      Index : constant Slot_Index := Slot_Of (Item, Id);
      Changed : constant Boolean :=
        not Item.Has_Focus
        or else Item.Active /= Index
        or else
          (Item.Panes (Index).Place = Floating
           and then Item.Top_Floating /= Index);
   begin
      Item.Active := Index;
      Item.Has_Focus := True;
      if Item.Panes (Index).Place = Floating then
         Item.Top_Floating := Index;
      end if;
      if Changed then
         Bump (Item);
      end if;
      Sync_Window_Focus (Item);
   end Focus_Pane;

   function Focused_Pane (Item : Model) return Pane_Id is
     (if Item.Count = 0 then Pane_Id'First else Item.Panes (Item.Active).Id);

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      if Item.Enabled = Enabled then
         return;
      end if;
      Item.Enabled := Enabled;
      for Index in Slot_Index loop
         if Item.Panes (Index).Used then
            Item.Panes (Index).Window.Set_Enabled (Enabled);
         end if;
      end loop;
      if not Enabled then
         Item.Capture_Mode :=
           (if Item.Capturing then Item.Capture_Mode else No_Internal_Capture);
         Item.Header_Drag := False;
         Item.Has_Drop_Target := False;
      end if;
      Bump (Item);
   end Set_Enabled;

   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   function Rail_Extent (Value : Dock_Side) return Natural is
     (if Value in Dock_Left | Dock_Right then 3 else 1);

   function Claimed
     (Desired, Available : Natural) return Natural
   is
     (if Available = 0 then 0
      elsif Available = 1 then 1
      else Natural'Min (Desired, Available - 1));

   procedure Compute_Geometry
     (Item   : Model;
      Panes  : out Pane_Geometry_Array;
      Center : out Flyology_TUI.Geometry.Rectangle)
   is
      Remaining : Flyology_TUI.Geometry.Rectangle := Bounds (Item);
      Amount : Natural;
      Index_Value : Natural;
      Index : Slot_Index;
   begin
      Panes := (others => <>);
      for Value in Dock_Side loop
         Index_Value := Occupant (Item, Value);
         if Index_Value /= 0 then
            Index := Slot_Index (Index_Value);
            Amount :=
              Claimed
                ((if Item.Panes (Index).Collapsed
                  then Rail_Extent (Value)
                  else Item.Panes (Index).Dock_Extent),
                 (if Value in Dock_Left | Dock_Right
                  then Remaining.Width else Remaining.Height));
            case Value is
               when Dock_Left =>
                  Panes (Index).Region :=
                    (Remaining.X, Remaining.Y, Amount, Remaining.Height);
                  Remaining.X := Remaining.X + Integer (Amount);
                  Remaining.Width := Remaining.Width - Amount;
               when Dock_Right =>
                  Panes (Index).Region :=
                    (Remaining.X + Integer (Remaining.Width - Amount),
                     Remaining.Y, Amount, Remaining.Height);
                  Remaining.Width := Remaining.Width - Amount;
               when Dock_Top =>
                  Panes (Index).Region :=
                    (Remaining.X, Remaining.Y, Remaining.Width, Amount);
                  Remaining.Y := Remaining.Y + Integer (Amount);
                  Remaining.Height := Remaining.Height - Amount;
               when Dock_Bottom =>
                  Panes (Index).Region :=
                    (Remaining.X,
                     Remaining.Y + Integer (Remaining.Height - Amount),
                     Remaining.Width, Amount);
                  Remaining.Height := Remaining.Height - Amount;
            end case;
            Panes (Index).Used := True;
            Panes (Index).Id := Item.Panes (Index).Id;
            Panes (Index).Header :=
              (Panes (Index).Region.X, Panes (Index).Region.Y,
               Panes (Index).Region.Width,
               Natural'Min (1, Panes (Index).Region.Height));
            if not Item.Panes (Index).Collapsed
              and then Panes (Index).Region.Height > 1
            then
               Panes (Index).Content_Region :=
                 (Panes (Index).Region.X, Panes (Index).Region.Y + 1,
                  Panes (Index).Region.Width,
                  Panes (Index).Region.Height - 1);
            end if;
            if Panes (Index).Header.Width > 0
              and then Item.Panes (Index).Collapsible
            then
               Panes (Index).Toggle_Action :=
                 (Panes (Index).Header.X, Panes (Index).Header.Y, 1, 1);
            end if;
            if Panes (Index).Header.Width > 1
              and then Item.Panes (Index).Floatable
            then
               Panes (Index).Float_Action :=
                 (Panes (Index).Header.X
                    + Integer (Panes (Index).Header.Width - 1),
                  Panes (Index).Header.Y, 1, 1);
            end if;
         end if;
      end loop;

      for Slot in Slot_Index loop
         if Item.Panes (Slot).Used
           and then Item.Panes (Slot).Place = Floating
         then
            Panes (Slot).Used := True;
            Panes (Slot).Id := Item.Panes (Slot).Id;
            Panes (Slot).Region := Item.Panes (Slot).Window.Bounds;
            Panes (Slot).Header :=
              (Panes (Slot).Region.X, Panes (Slot).Region.Y,
               Panes (Slot).Region.Width,
               Natural'Min (1, Panes (Slot).Region.Height));
            Panes (Slot).Content_Region :=
              Item.Panes (Slot).Window.Client_Region;
            if Panes (Slot).Header.Width > 1 then
               Panes (Slot).Float_Action :=
                 (Panes (Slot).Header.X
                    + Integer (Panes (Slot).Header.Width - 2),
                  Panes (Slot).Header.Y, 1, 1);
            end if;
         end if;
      end loop;
      Center := Remaining;
   end Compute_Geometry;

   function Child
     (Children : Surface_Array; Id : Pane_Id)
      return Flyology_TUI.Surfaces.Surface
   is
   begin
      if Id not in Children'Range then
         raise Flyology_TUI.Components.Structure_Error with
           "dock child does not match configured pane ID";
      end if;
      return Children (Id);
   end Child;

   procedure Paint_Dock
     (Result     : in out Flyology_TUI.Surfaces.Surface;
      Item       : Model;
      Geometry   : Pane_Geometry_Array;
      Index      : Slot_Index;
      Content    : Flyology_TUI.Surfaces.Surface;
      Look       : Appearance)
   is
      State : Pane_State renames Item.Panes (Index);
      Area  : Pane_Geometry renames Geometry (Index);
      Header_Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled then Look.Disabled
         elsif Item.Has_Focus and then Item.Active = Index
         then Look.Focused_Header else Look.Header);
      Rail_Style : constant Flyology_TUI.Styles.Style :=
        (if not Item.Enabled then Look.Disabled
         elsif Item.Has_Focus and then Item.Active = Index
         then Look.Focused_Rail else Look.Rail);
      Layer : Flyology_TUI.Surfaces.Surface;
      Header : Flyology_TUI.Surfaces.Surface;
   begin
      if Area.Region.Width = 0 or else Area.Region.Height = 0 then
         return;
      end if;
      Layer := Flyology_TUI.Surfaces.Create
        (Area.Region.Width, Area.Region.Height,
         (if State.Collapsed then Rail_Style else Look.Dock));
      if State.Collapsed then
         Layer.Put (0, 0, "+", Rail_Style);
         if State.Dock in Dock_Left | Dock_Right then
            declare
               Name : constant Wide_Wide_String := Label (State.Id);
            begin
               declare
                  Count : constant Natural := Natural'Min
                    (Name'Length, Area.Region.Height - 1);
               begin
                  if Count > 0 then
                     for Offset in 0 .. Count - 1 loop
                        Layer.Put
                          (Natural'Min (1, Area.Region.Width - 1), Offset + 1,
                           Name (Name'First + Offset) & "", Rail_Style);
                     end loop;
                  end if;
               end;
            end;
         elsif Area.Region.Width > 2 then
            Layer.Write (2, 0, Label (State.Id), Rail_Style);
         end if;
      else
         Header := Flyology_TUI.Surfaces.Create
           (Area.Header.Width, Area.Header.Height, Header_Style);
         if Area.Header.Width > 0 and then Area.Header.Height > 0 then
            if State.Collapsible then
               Header.Put (0, 0, "-", Look.Action);
            end if;
            if Area.Header.Width > 2 then
               Header.Write (2, 0, Label (State.Id), Header_Style);
            end if;
            if Area.Header.Width > 1 and then State.Floatable then
               Header.Put (Area.Header.Width - 1, 0, "^", Look.Action);
            end if;
            Layer.Overlay_Clipped (Header, 0, 0);
         end if;
         if Area.Content_Region.Width > 0
           and then Area.Content_Region.Height > 0
         then
            Layer.Overlay_Clipped (Content, 0, 1);
         end if;
      end if;
      Result.Overlay_Clipped (Layer, Area.Region.X, Area.Region.Y);
   end Paint_Dock;

   procedure Paint_Floating
     (Result   : in out Flyology_TUI.Surfaces.Surface;
      Item     : Model;
      Geometry : Pane_Geometry_Array;
      Index    : Slot_Index;
      Content  : Flyology_TUI.Surfaces.Surface;
      Look     : Appearance)
   is
      Area : constant Flyology_TUI.Geometry.Rectangle :=
        Geometry (Index).Region;
      Window : constant Flyology_TUI.Surfaces.Surface :=
        Item.Panes (Index).Window.Render
          (Label (Item.Panes (Index).Id), Content, Area,
           Look.Floating_Window);
   begin
      Result.Overlay_Clipped (Window, Area.X, Area.Y);
      if Geometry (Index).Float_Action.Width > 0
        and then Geometry (Index).Float_Action.X >= 0
        and then Geometry (Index).Float_Action.Y >= 0
        and then Natural (Geometry (Index).Float_Action.X) < Result.Width
        and then Natural (Geometry (Index).Float_Action.Y) < Result.Height
      then
         Result.Put
           (Natural (Geometry (Index).Float_Action.X),
            Natural (Geometry (Index).Float_Action.Y), "v", Look.Action);
      end if;
   end Paint_Floating;

   procedure Paint_Drop_Target
     (Result : in out Flyology_TUI.Surfaces.Surface;
      Side   : Dock_Side;
      Style  : Flyology_TUI.Styles.Style)
   is
   begin
      if Result.Width = 0 or else Result.Height = 0 then
         return;
      end if;
      case Side is
         when Dock_Left | Dock_Right =>
            declare
               X : constant Natural :=
                 (if Side = Dock_Left then 0 else Result.Width - 1);
            begin
               for Y in 0 .. Result.Height - 1 loop
                  Result.Put (X, Y, ":", Style);
               end loop;
            end;
         when Dock_Top | Dock_Bottom =>
            declare
               Y : constant Natural :=
                 (if Side = Dock_Top then 0 else Result.Height - 1);
            begin
               for X in 0 .. Result.Width - 1 loop
                  Result.Put (X, Y, ":", Style);
               end loop;
            end;
      end case;
   end Paint_Drop_Target;

   function Present
     (Item       : Model;
      Children   : Surface_Array;
      Appearance : Dock_Workspaces.Appearance) return Presentation
   is
      Result : Presentation;
      Top : constant Slot_Index := Item.Top_Floating;
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used
           and then Item.Panes (Index).Id not in Children'Range
         then
            raise Flyology_TUI.Components.Structure_Error with
              "dock children do not cover configured pane IDs";
         end if;
      end loop;
      Result.Image := Flyology_TUI.Surfaces.Create
        (Item.Columns, Item.Rows, Appearance.Workspace);
      Result.Workspace := Bounds (Item);
      Result.Version := Item.Revision;
      Compute_Geometry (Item, Result.Panes, Result.Center);

      for Index in Slot_Index loop
         if Item.Panes (Index).Used
           and then Item.Panes (Index).Place = Docked
         then
            Paint_Dock
              (Result.Image, Item, Result.Panes, Index,
               Child (Children, Item.Panes (Index).Id), Appearance);
         end if;
      end loop;
      for Index in Slot_Index loop
         if Item.Panes (Index).Used
           and then Item.Panes (Index).Place = Floating
           and then Index /= Top
         then
            Paint_Floating
              (Result.Image, Item, Result.Panes, Index,
               Child (Children, Item.Panes (Index).Id), Appearance);
         end if;
      end loop;
      if Item.Panes (Top).Used and then Item.Panes (Top).Place = Floating then
         Paint_Floating
           (Result.Image, Item, Result.Panes, Top,
            Child (Children, Item.Panes (Top).Id), Appearance);
      end if;
      if Item.Has_Drop_Target then
         Paint_Drop_Target
           (Result.Image, Item.Drop_Target_Side, Appearance.Drop_Target);
      end if;
      return Result;
   end Present;

   function Present
     (Item     : Model;
      Children : Surface_Array;
      Theme    : Flyology_TUI.Themes.Theme) return Presentation
   is (Present (Item, Children, From_Theme (Theme)));

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface is
     (Item.Image);
   function Center_Region
     (Item : Presentation) return Flyology_TUI.Geometry.Rectangle is
     (Item.Center);

   function Has_Pane
     (Item : Presentation; Id : Pane_Id) return Boolean is
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used and then Item.Panes (Index).Id = Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Pane;

   function Presentation_Slot
     (Item : Presentation; Id : Pane_Id) return Slot_Index
   is
   begin
      for Index in Slot_Index loop
         if Item.Panes (Index).Used and then Item.Panes (Index).Id = Id then
            return Index;
         end if;
      end loop;
      raise Flyology_TUI.Components.Structure_Error with
        "unknown dock presentation pane ID";
   end Presentation_Slot;

   function Pane_Region
     (Item : Presentation; Id : Pane_Id)
      return Flyology_TUI.Geometry.Rectangle
   is (Item.Panes (Presentation_Slot (Item, Id)).Content_Region);

   function Header_Region
     (Item : Presentation; Id : Pane_Id)
      return Flyology_TUI.Geometry.Rectangle
   is (Item.Panes (Presentation_Slot (Item, Id)).Header);

   function Next_Used
     (Item : Model; Start : Slot_Index; Backwards : Boolean)
      return Slot_Index
   is
      Candidate : Slot_Index := Start;
   begin
      for Count in 1 .. Maximum_Panes loop
         if Backwards then
            Candidate :=
              (if Candidate = Slot_Index'First
               then Slot_Index'Last else Candidate - 1);
         else
            Candidate :=
              (if Candidate = Slot_Index'Last
               then Slot_Index'First else Candidate + 1);
         end if;
         exit when Item.Panes (Candidate).Used;
      end loop;
      return Candidate;
   end Next_Used;

   function Key_Side
     (Kind : Flyology_TUI.Events.Key_Kind; Value : out Dock_Side)
      return Boolean
   is
   begin
      case Kind is
         when Flyology_TUI.Events.Arrow_Left_Key  => Value := Dock_Left;
         when Flyology_TUI.Events.Arrow_Right_Key => Value := Dock_Right;
         when Flyology_TUI.Events.Arrow_Up_Key    => Value := Dock_Top;
         when Flyology_TUI.Events.Arrow_Down_Key  => Value := Dock_Bottom;
         when others => return False;
      end case;
      return True;
   end Key_Side;

   function Is_F_Key (Event : Flyology_TUI.Events.Terminal_Event)
      return Boolean
   is
   begin
      return Event.Kind = Flyology_TUI.Events.Key_Press
        and then Event.Key.Kind = Flyology_TUI.Events.Text_Key
        and then Text.Length (Event.Key.Value) = 1
        and then Text.Element (Event.Key.Value, 1) in 'f' | 'F';
   end Is_F_Key;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Revision_Number := Item.Revision;
      Target_Side : Dock_Side := Dock_Left;
      Window_Result : Flyology_TUI.Components.Interactions.Update_Result;
   begin
      if not Item.Enabled or else not Item.Has_Focus or else Item.Count = 0
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
      then
         return Result;
      end if;
      if Item.Panes (Item.Active).Place = Floating then
         Window_Result := Item.Panes (Item.Active).Window.Handle
           (Event, Bounds (Item));
         if Window_Result.Handled then
            Result := Window_Result;
            if Result.Changed then
               Bump (Item);
            end if;
            return Result;
         end if;
      end if;

      if Event.Key.Kind = Flyology_TUI.Events.Tab_Key then
         Item.Active := Next_Used
           (Item, Item.Active, Event.Key.Modified.Shift);
         if Item.Panes (Item.Active).Place = Floating then
            Item.Top_Floating := Item.Active;
         end if;
         Bump (Item);
         Result.Handled := True;
      elsif Event.Key.Kind = Flyology_TUI.Events.Enter_Key
        and then Item.Panes (Item.Active).Place = Docked
      then
         Toggle_Index (Item, Item.Active);
         Result.Handled := True;
         Result.Activated := Item.Revision /= Before;
      elsif Is_F_Key (Event) then
         Result.Handled := True;
         if Item.Panes (Item.Active).Place = Docked then
            if Item.Panes (Item.Active).Floatable then
               Float_Index (Item, Item.Active);
               Result.Activated := Item.Revision /= Before;
            else
               Result.Rejected := True;
            end if;
         elsif Occupant
           (Item, Item.Panes (Item.Active).Dock, Item.Active) = 0
         then
            Dock_Index
              (Item, Item.Active, Item.Panes (Item.Active).Dock);
            Result.Activated := Item.Revision /= Before;
         else
            Result.Rejected := True;
         end if;
      elsif Event.Key.Modified.Shift
        and then Key_Side (Event.Key.Kind, Target_Side)
      then
         Result.Handled := True;
         if Occupant (Item, Target_Side, Item.Active) = 0 then
            Dock_Index (Item, Item.Active, Target_Side);
            Result.Activated := Item.Revision /= Before;
         else
            Result.Rejected := True;
         end if;
      end if;
      Result.Changed := Item.Revision /= Before;
      if Result.Changed then
         Sync_Window_Focus (Item);
      end if;
      return Result;
   end Handle;

   function Edge_At
     (Workspace : Flyology_TUI.Geometry.Rectangle;
      Point     : Flyology_TUI.Geometry.Point;
      Value     : out Dock_Side) return Boolean
   is
      Last_X : constant Integer :=
        Workspace.X + Integer (Workspace.Width) - 1;
      Last_Y : constant Integer :=
        Workspace.Y + Integer (Workspace.Height) - 1;
   begin
      if Workspace.Width = 0 or else Workspace.Height = 0 then
         return False;
      elsif Point.X <= Workspace.X then
         Value := Dock_Left;
      elsif Point.X >= Last_X then
         Value := Dock_Right;
      elsif Point.Y <= Workspace.Y then
         Value := Dock_Top;
      elsif Point.Y >= Last_Y then
         Value := Dock_Bottom;
      else
         return False;
      end if;
      return True;
   end Edge_At;

   function Handle
     (Item   : in out Model;
      Layout : Presentation;
      Event  : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result
   is
      Result : Flyology_TUI.Components.Interactions.Update_Result;
      Before : constant Revision_Number := Item.Revision;
      Point  : constant Flyology_TUI.Geometry.Point := (Event.X, Event.Y);
      Target_Side : Dock_Side := Dock_Left;
      Index : Slot_Index;

      procedure Select_Pane (Value : Slot_Index) is
         Changed : constant Boolean :=
           not Item.Has_Focus
           or else Item.Active /= Value
           or else
             (Item.Panes (Value).Place = Floating
              and then Item.Top_Floating /= Value);
      begin
         Item.Active := Value;
         Item.Has_Focus := True;
         if Item.Panes (Value).Place = Floating then
            Item.Top_Floating := Value;
         end if;
         Sync_Window_Focus (Item);
         if Changed then
            Bump (Item);
         end if;
         Result.Focus_Requested := True;
      end Select_Pane;

      procedure Finish_Action is
         Hit : constant Boolean :=
           Flyology_TUI.Geometry.Contains (Item.Press_Region, Point);
      begin
         Index := Item.Captured;
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         Item.Capturing := False;
         if Item.Enabled
           and then Hit
           and then Item.Revision = Item.Capture_Revision
         then
            if Item.Capture_Mode = Toggle_Action_Interaction then
               Toggle_Index (Item, Index);
               Result.Activated := Item.Revision /= Before;
            elsif Item.Capture_Mode = Float_Action_Interaction then
               if Item.Panes (Index).Place = Docked then
                  Float_Index (Item, Index);
                  Result.Activated := Item.Revision /= Before;
               elsif Occupant
                 (Item, Item.Panes (Index).Dock, Index) = 0
               then
                  Dock_Index (Item, Index, Item.Panes (Index).Dock);
                  Result.Activated := Item.Revision /= Before;
               else
                  Result.Rejected := True;
               end if;
            end if;
         end if;
         Item.Capture_Mode := No_Internal_Capture;
      end Finish_Action;

      procedure Route_Window (Value : Slot_Index) is
         Window_Result : Flyology_TUI.Components.Interactions.Update_Result;
         Area : constant Flyology_TUI.Geometry.Rectangle :=
           Item.Panes (Value).Window.Bounds;
      begin
         Select_Pane (Value);
         Item.Header_Drag :=
           Event.Action = Flyology_TUI.Events.Mouse_Click
           and then Event.Button = Flyology_TUI.Events.Left_Button
           and then Event.Y = Area.Y
           and then Event.X >= Area.X + 2
           and then Event.X < Area.X + Integer (Area.Width) - 2;
         Item.Has_Drop_Target := False;
         Window_Result := Item.Panes (Value).Window.Handle
           (Event, Bounds (Item));
         Result := Window_Result;
         Result.Focus_Requested := True;
         if Window_Result.Capture =
           Flyology_TUI.Components.Interactions.Acquire_Capture
         then
            Item.Capturing := True;
            Item.Captured := Value;
            Item.Capture_Mode := Window_Interaction;
         end if;
         Result.Changed := Result.Changed or else Item.Revision /= Before;
      end Route_Window;
   begin
      if Item.Capturing
        and then Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Event.Button = Flyology_TUI.Events.Left_Button
      then
         if Item.Capture_Mode in
           Float_Action_Interaction | Toggle_Action_Interaction
         then
            Finish_Action;
         else
            Index := Item.Captured;
            Result := Item.Panes (Index).Window.Handle
              (Event, Bounds (Item));
            Item.Capturing := False;
            Item.Capture_Mode := No_Internal_Capture;
            if Item.Enabled and then Item.Header_Drag
              and then Edge_At (Bounds (Item), Point, Target_Side)
              and then Occupant (Item, Target_Side, Index) = 0
            then
               Dock_Index (Item, Index, Target_Side);
               Result.Activated := Item.Revision /= Before;
            elsif Item.Has_Drop_Target then
               Item.Has_Drop_Target := False;
               Bump (Item);
            end if;
            Item.Header_Drag := False;
         end if;
         Result.Handled := True;
         Result.Capture :=
           Flyology_TUI.Components.Interactions.Release_Capture;
         Result.Changed := Item.Revision /= Before or else Result.Changed;
         return Result;
      elsif Item.Capturing then
         if Item.Capture_Mode = Window_Interaction then
            Result := Item.Panes (Item.Captured).Window.Handle
              (Event, Bounds (Item));
            if Result.Changed then
               Bump (Item);
            end if;
            if Item.Header_Drag
              and then Event.Action = Flyology_TUI.Events.Mouse_Drag
            then
               declare
                  Has_Target : constant Boolean :=
                    Edge_At (Bounds (Item), Point, Target_Side)
                    and then Occupant
                      (Item, Target_Side, Item.Captured) = 0;
                  Target_Changed : constant Boolean :=
                    Item.Has_Drop_Target /= Has_Target
                    or else
                      (Has_Target
                       and then Item.Drop_Target_Side /= Target_Side);
               begin
                  Item.Has_Drop_Target := Has_Target;
                  if Has_Target then
                     Item.Drop_Target_Side := Target_Side;
                  end if;
                  if Target_Changed then
                     Bump (Item);
                     Result.Changed := True;
                  end if;
               end;
            end if;
         end if;
         return Result;
      elsif Layout.Version /= Item.Revision then
         Result.Rejected := True;
         return Result;
      elsif not Item.Enabled then
         return Result;
      end if;

      --  Floating windows route topmost first. Child bodies pass through.
      for Pass in 0 .. Item.Count loop
         Index :=
           (if Pass = 0 then Item.Top_Floating
            else Slot_Index (Natural'Min (Pass, Maximum_Panes)));
         if Item.Panes (Index).Used
           and then Item.Panes (Index).Place = Floating
           and then (Pass = 0 or else Index /= Item.Top_Floating)
           and then Flyology_TUI.Geometry.Contains
             (Layout.Panes (Index).Region, Point)
         then
            if Flyology_TUI.Geometry.Contains
              (Layout.Panes (Index).Float_Action, Point)
              and then Event.Action = Flyology_TUI.Events.Mouse_Click
              and then Event.Button = Flyology_TUI.Events.Left_Button
            then
               Select_Pane (Index);
               Item.Capturing := True;
               Item.Captured := Index;
               Item.Capture_Mode := Float_Action_Interaction;
               Item.Press_Region := Layout.Panes (Index).Float_Action;
               Item.Capture_Revision := Item.Revision;
               Result.Handled := True;
               Result.Capture :=
                 Flyology_TUI.Components.Interactions.Acquire_Capture;
               Result.Changed := Item.Revision /= Before;
               return Result;
            elsif Flyology_TUI.Geometry.Contains
              (Layout.Panes (Index).Content_Region, Point)
            then
               return Result;
            else
               Route_Window (Index);
               if Result.Changed then
                  Bump (Item);
               end if;
               return Result;
            end if;
         end if;
      end loop;

      for Slot in Slot_Index loop
         if Item.Panes (Slot).Used
           and then Item.Panes (Slot).Place = Docked
           and then Flyology_TUI.Geometry.Contains
             (Layout.Panes (Slot).Region, Point)
         then
            if Flyology_TUI.Geometry.Contains
              (Layout.Panes (Slot).Content_Region, Point)
            then
               return Result;
            end if;
            Select_Pane (Slot);
            Result.Handled := True;
            if Event.Action = Flyology_TUI.Events.Mouse_Click
              and then Event.Button = Flyology_TUI.Events.Left_Button
            then
               if Flyology_TUI.Geometry.Contains
                 (Layout.Panes (Slot).Float_Action, Point)
                 and then Item.Panes (Slot).Floatable
               then
                  Item.Capture_Mode := Float_Action_Interaction;
                  Item.Press_Region := Layout.Panes (Slot).Float_Action;
               else
                  Item.Capture_Mode := Toggle_Action_Interaction;
                  Item.Press_Region :=
                    (if Item.Panes (Slot).Collapsed
                     then Layout.Panes (Slot).Region
                     else Layout.Panes (Slot).Toggle_Action);
               end if;
               if Flyology_TUI.Geometry.Contains
                 (Item.Press_Region, Point)
               then
                  Item.Capturing := True;
                  Item.Captured := Slot;
                  Item.Capture_Revision := Item.Revision;
                  Result.Capture :=
                    Flyology_TUI.Components.Interactions.Acquire_Capture;
               else
                  Item.Capture_Mode := No_Internal_Capture;
               end if;
            end if;
            Result.Changed := Item.Revision /= Before;
            return Result;
         end if;
      end loop;
      Result.Changed := Item.Revision /= Before;
      return Result;
   end Handle;
end Flyology_TUI.Components.Dock_Workspaces;
