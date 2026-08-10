with Ada.Containers;
with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Glyphs;

package body Flyology_TUI.Components.Menubars is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;
   use type Ada.Containers.Count_Type;
   use type Flyology_TUI.Events.Key_Kind;
   use type Flyology_TUI.Events.Mouse_Action;
   use type Flyology_TUI.Events.Mouse_Button;
   use type Flyology_TUI.Events.Terminal_Event_Kind;
   use type Revision_Number;

   function Action
     (Id : Item_Id; Menu : Menu_Id; Enabled : Boolean := True)
      return Item_Definition is
     ((Kind => Action_Item, Id => Id, Menu => Menu, Enabled => Enabled));

   function Separator (Id : Item_Id; Menu : Menu_Id) return Item_Definition is
     ((Kind => Separator_Item, Id => Id, Menu => Menu, Enabled => False));

   function Check
     (Id      : Item_Id;
      Menu    : Menu_Id;
      Checked : Boolean := False;
      Enabled : Boolean := True) return Item_Definition is
     ((Kind => Check_Item, Id => Id, Menu => Menu, Enabled => Enabled,
       Checked => Checked));

   function Radio
     (Id       : Item_Id;
      Menu     : Menu_Id;
      Group    : Item_Id;
      Selected : Boolean := False;
      Enabled  : Boolean := True) return Item_Definition is
     ((Kind => Radio_Item, Id => Id, Menu => Menu, Enabled => Enabled,
       Group => Group, Selected => Selected));

   function Submenu
     (Id      : Item_Id;
      Menu    : Menu_Id;
      Child   : Menu_Id;
      Enabled : Boolean := True) return Item_Definition is
     ((Kind => Submenu_Item, Id => Id, Menu => Menu, Enabled => Enabled,
       Child => Child));

   function Store (Item : Item_Definition) return Stored_Item is
     ((Kind    => Item.Kind,
       Id      => Item.Id,
       Menu    => Item.Menu,
       Enabled => Item.Enabled,
       State   =>
         (if Item.Kind = Check_Item then Item.Checked
          elsif Item.Kind = Radio_Item then Item.Selected
          else False),
       Group   =>
         (if Item.Kind = Radio_Item then Item.Group else Item.Id),
       Child   =>
         (if Item.Kind = Submenu_Item then Item.Child else Item.Menu)));

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance is
     (Bar         => Theme.Primary,
      Menu        => Theme.Primary,
      Focused     => Theme.Focused,
      Highlighted => Theme.Selected,
      Disabled    => Theme.Muted,
      Separator   => Theme.Border,
      Shortcut    => Theme.Muted,
      Marker      => Theme.Success);

   function Find_Menu
     (Values : Menu_Vectors.Vector; Id : Menu_Id) return Natural is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Values.Element (Index).Id = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Find_Menu;

   function Find_Item
     (Values : Item_Vectors.Vector; Id : Item_Id) return Natural is
   begin
      if Values.Is_Empty then
         return 0;
      end if;
      for Index in 0 .. Natural (Values.Length) - 1 loop
         if Values.Element (Index).Id = Id then
            return Index + 1;
         end if;
      end loop;
      return 0;
   end Find_Item;

   function Is_Selectable
     (Item : Model; Index : Natural) return Boolean is
     (Index > 0
      and then Index <= Natural (Item.Items.Length)
      and then Item.Items.Element (Index - 1).Enabled
      and then Item.Items.Element (Index - 1).Kind /= Separator_Item);

   function First_Item
     (Item : Model; Menu_Index : Natural; Selectable_Only : Boolean)
      return Natural is
   begin
      if Menu_Index = 0 or else Item.Items.Is_Empty then
         return 0;
      end if;
      for Index in 1 .. Natural (Item.Items.Length) loop
         if Item.Items.Element (Index - 1).Menu =
              Item.Menus.Element (Menu_Index - 1).Id
           and then (not Selectable_Only or else Is_Selectable (Item, Index))
         then
            return Index;
         end if;
      end loop;
      return 0;
   end First_Item;

   function Last_Item
     (Item : Model; Menu_Index : Natural; Selectable_Only : Boolean)
      return Natural is
   begin
      if Menu_Index = 0 or else Item.Items.Is_Empty then
         return 0;
      end if;
      for Index in reverse 1 .. Natural (Item.Items.Length) loop
         if Item.Items.Element (Index - 1).Menu =
              Item.Menus.Element (Menu_Index - 1).Id
           and then (not Selectable_Only or else Is_Selectable (Item, Index))
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Last_Item;

   function Next_Item
     (Item       : Model;
      Menu_Index : Natural;
      From       : Natural;
      Step       : Integer) return Natural
   is
      Cursor : Integer := Integer (From) + Step;
      Limit  : constant Integer := Integer (Item.Items.Length);
   begin
      while Cursor >= 1 and then Cursor <= Limit loop
         if Item.Items.Element (Natural (Cursor) - 1).Menu =
              Item.Menus.Element (Menu_Index - 1).Id
           and then Is_Selectable (Item, Natural (Cursor))
         then
            return Natural (Cursor);
         end if;
         Cursor := Cursor + Step;
      end loop;
      return From;
   end Next_Item;

   function First_Top (Item : Model) return Natural is
   begin
      if Item.Menus.Is_Empty then
         return 0;
      end if;
      for Index in 1 .. Natural (Item.Menus.Length) loop
         if Item.Menus.Element (Index - 1).Top_Level
           and then Item.Menus.Element (Index - 1).Enabled
         then
            return Index;
         end if;
      end loop;
      return 0;
   end First_Top;

   function Last_Top (Item : Model) return Natural is
   begin
      if Item.Menus.Is_Empty then
         return 0;
      end if;
      for Index in reverse 1 .. Natural (Item.Menus.Length) loop
         if Item.Menus.Element (Index - 1).Top_Level
           and then Item.Menus.Element (Index - 1).Enabled
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Last_Top;

   function Next_Top
     (Item : Model; From : Natural; Step : Integer) return Natural
   is
      Cursor : Integer := Integer (From) + Step;
      Limit  : constant Integer := Integer (Item.Menus.Length);
   begin
      while Cursor >= 1 and then Cursor <= Limit loop
         if Item.Menus.Element (Natural (Cursor) - 1).Top_Level
           and then Item.Menus.Element (Natural (Cursor) - 1).Enabled
         then
            return Natural (Cursor);
         end if;
         Cursor := Cursor + Step;
      end loop;
      return From;
   end Next_Top;

   procedure Validate
     (Menus : Menu_Array; Items : Item_Array)
   is
      Menu_Values : Menu_Vectors.Vector;
      Item_Values : Item_Vectors.Vector;
      type Flag_Array is array (Positive range <>) of Boolean;
      Reached : Flag_Array (1 .. Maximum_Menus) := (others => False);
      Path    : Flag_Array (1 .. Maximum_Menus) := (others => False);

      procedure Walk (Menu_Index : Positive; Depth : Positive) is
      begin
         if Depth > Maximum_Depth then
            raise Flyology_TUI.Components.Capacity_Error;
         elsif Path (Menu_Index) then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
         Path (Menu_Index) := True;
         Reached (Menu_Index) := True;
         if not Item_Values.Is_Empty then
            for Index in 0 .. Natural (Item_Values.Length) - 1 loop
               declare
                  Definition : constant Stored_Item :=
                    Item_Values.Element (Index);
               begin
                  if Definition.Menu = Menu_Values.Element
                       (Menu_Index - 1).Id
                    and then Definition.Kind = Submenu_Item
                  then
                     declare
                        Child : constant Positive := Positive
                          (Find_Menu (Menu_Values, Definition.Child));
                     begin
                        if Path (Child) then
                           raise Flyology_TUI.Components.Structure_Error;
                        elsif Depth = Maximum_Depth then
                           raise Flyology_TUI.Components.Capacity_Error with
                             "submenu exceeds Maximum_Depth";
                        end if;
                        Walk (Child, Depth + 1);
                     end;
                  end if;
               end;
            end loop;
         end if;
         Path (Menu_Index) := False;
      end Walk;
   begin
      if Menus'Length > Maximum_Menus
        or else Items'Length > Maximum_Items
      then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      for Definition of Menus loop
         if Find_Menu (Menu_Values, Definition.Id) /= 0 then
            raise Flyology_TUI.Components.Structure_Error;
         end if;
         Menu_Values.Append (Definition);
      end loop;
      for Definition of Items loop
         if Find_Item (Item_Values, Definition.Id) /= 0
           or else Find_Menu (Menu_Values, Definition.Menu) = 0
         then
            raise Flyology_TUI.Components.Structure_Error;
         elsif Definition.Kind = Submenu_Item then
            declare
               Child : constant Natural :=
                 Find_Menu (Menu_Values, Definition.Child);
            begin
               if Child = 0
                 or else Menu_Values.Element (Child - 1).Top_Level
               then
                  raise Flyology_TUI.Components.Structure_Error;
               end if;
            end;
         end if;
         if Definition.Kind = Radio_Item and then Definition.Selected then
            for Prior of Item_Values loop
               if Prior.Kind = Radio_Item
                 and then Prior.Menu = Definition.Menu
                 and then Prior.Group = Definition.Group
                 and then Prior.State
               then
                  raise Flyology_TUI.Components.Structure_Error;
               end if;
            end loop;
         end if;
         Item_Values.Append (Store (Definition));
      end loop;

      if not Menu_Values.Is_Empty then
         for Index in 1 .. Natural (Menu_Values.Length) loop
            if Menu_Values.Element (Index - 1).Top_Level then
               Walk (Index, 1);
            end if;
         end loop;
         for Index in 1 .. Natural (Menu_Values.Length) loop
            if not Reached (Index) then
               raise Flyology_TUI.Components.Structure_Error;
            end if;
         end loop;
      end if;
   end Validate;

   procedure Invalidate_Presentation (Item : in out Model) is
   begin
      Item.Presentation_Revision := Item.Presentation_Revision + 1;
   end Invalidate_Presentation;

   procedure Clear_Open_State (Item : in out Model) is
   begin
      Item.Open_Menus.Clear;
      Item.Highlights.Clear;
      Item.Armed_Menu := 0;
      Item.Armed_Item := 0;
   end Clear_Open_State;

   procedure Set_Content
     (Item : in out Model; Menus : Menu_Array; Items : Item_Array)
   is
      New_Menus      : Menu_Vectors.Vector;
      New_Items      : Item_Vectors.Vector;
      New_State      : Boolean_Vectors.Vector;
      New_Open       : Natural_Vectors.Vector;
      New_Highlights : Natural_Vectors.Vector;
      New_Focused    : Natural := 0;
      Valid_Path     : Boolean := True;
   begin
      Validate (Menus, Items);
      for Definition of Menus loop
         declare
            Value : Menu_Definition := Definition;
            Old   : constant Natural := Find_Menu (Item.Menus, Definition.Id);
         begin
            if Old > 0 then
               Value.Enabled := Item.Menus.Element (Old - 1).Enabled;
            end if;
            New_Menus.Append (Value);
         end;
      end loop;
      for Definition of Items loop
         declare
            Old    : constant Natural := Find_Item (Item.Items, Definition.Id);
            Stored : Stored_Item := Store (Definition);
            State  : Boolean :=
              (if Definition.Kind = Check_Item then Definition.Checked
               elsif Definition.Kind = Radio_Item then Definition.Selected
               else False);
         begin
            if Old > 0
              and then Item.Items.Element (Old - 1).Kind = Definition.Kind
            then
               Stored.Enabled := Item.Items.Element (Old - 1).Enabled;
               if Definition.Kind in Check_Item | Radio_Item then
                  State := Item.Item_State.Element (Old - 1);
               end if;
            end if;
            New_Items.Append (Stored);
            New_State.Append (State);
         end;
      end loop;
      if not New_Items.Is_Empty then
         for Left in 1 .. Natural (New_Items.Length) loop
            if New_Items.Element (Left - 1).Kind = Radio_Item
              and then New_State.Element (Left - 1)
            then
               for Right in Left + 1 .. Natural (New_Items.Length) loop
                  if New_Items.Element (Right - 1).Kind = Radio_Item
                    and then New_State.Element (Right - 1)
                    and then New_Items.Element (Right - 1).Menu =
                      New_Items.Element (Left - 1).Menu
                    and then New_Items.Element (Right - 1).Group =
                      New_Items.Element (Left - 1).Group
                  then
                     raise Flyology_TUI.Components.Structure_Error;
                  end if;
               end loop;
            end if;
         end loop;
      end if;

      if Item.Focused > 0 then
         New_Focused := Find_Menu
           (New_Menus, Item.Menus.Element (Item.Focused - 1).Id);
         if New_Focused > 0
           and then (not New_Menus.Element (New_Focused - 1).Top_Level
                     or else not New_Menus.Element (New_Focused - 1).Enabled)
         then
            New_Focused := 0;
         end if;
      end if;
      if New_Focused = 0 and then not New_Menus.Is_Empty then
         for Index in 1 .. Natural (New_Menus.Length) loop
            if New_Menus.Element (Index - 1).Top_Level
              and then New_Menus.Element (Index - 1).Enabled
            then
               New_Focused := Index;
               exit;
            end if;
         end loop;
      end if;

      if not Item.Open_Menus.Is_Empty then
         for Depth in 1 .. Natural (Item.Open_Menus.Length) loop
            exit when not Valid_Path;
            declare
               Old_Menu : constant Natural := Item.Open_Menus.Element
                 (Depth - 1);
               Old_Highlight : constant Natural := Item.Highlights.Element
                 (Depth - 1);
               New_Menu : constant Natural := Find_Menu
                 (New_Menus, Item.Menus.Element (Old_Menu - 1).Id);
               New_Highlight : constant Natural :=
                 (if Old_Highlight = 0 then 0
                  else Find_Item
                    (New_Items, Item.Items.Element (Old_Highlight - 1).Id));
            begin
               Valid_Path := New_Menu > 0
                 and then New_Menus.Element (New_Menu - 1).Enabled;
               if Depth = 1 then
                  Valid_Path := Valid_Path
                    and then New_Menus.Element (New_Menu - 1).Top_Level;
               else
                  declare
                     Parent_Item : constant Natural :=
                       New_Highlights.Element (Depth - 2);
                  begin
                     Valid_Path := Valid_Path
                       and then Parent_Item > 0
                       and then New_Items.Element (Parent_Item - 1).Kind =
                         Submenu_Item
                       and then New_Items.Element (Parent_Item - 1).Child =
                         New_Menus.Element (New_Menu - 1).Id;
                  end;
               end if;
               if Valid_Path then
                  if New_Highlight > 0
                    and then
                      (New_Items.Element (New_Highlight - 1).Menu /=
                         New_Menus.Element (New_Menu - 1).Id
                       or else not New_Items.Element
                         (New_Highlight - 1).Enabled
                       or else New_Items.Element (New_Highlight - 1).Kind =
                         Separator_Item)
                  then
                     Valid_Path := False;
                  else
                     New_Open.Append (New_Menu);
                     New_Highlights.Append (New_Highlight);
                  end if;
               end if;
            end;
         end loop;
      end if;

      if not Valid_Path then
         New_Open.Clear;
         New_Highlights.Clear;
      end if;
      Item.Menus := New_Menus;
      Item.Items := New_Items;
      Item.Item_State := New_State;
      Item.Open_Menus := New_Open;
      Item.Highlights := New_Highlights;
      Item.Focused := New_Focused;
      Item.Armed_Menu := 0;
      Item.Armed_Item := 0;
      Item.Presentation_Revision := Item.Presentation_Revision + 1;
   end Set_Content;

   function Create
     (Menus : Menu_Array; Items : Item_Array; Enabled : Boolean := True)
      return Model
   is
      Result : Model;
   begin
      Result.Enabled := Enabled;
      Set_Content (Result, Menus, Items);
      return Result;
   end Create;

   function Menu_Count (Item : Model) return Natural is
     (Natural (Item.Menus.Length));
   function Item_Count (Item : Model) return Natural is
     (Natural (Item.Items.Length));
   function Contains_Menu (Item : Model; Id : Menu_Id) return Boolean is
     (Find_Menu (Item.Menus, Id) > 0);
   function Contains_Item (Item : Model; Id : Item_Id) return Boolean is
     (Find_Item (Item.Items, Id) > 0);
   function Is_Enabled (Item : Model) return Boolean is (Item.Enabled);

   procedure Close (Item : in out Model) is
   begin
      if not Item.Open_Menus.Is_Empty
        or else not Item.Highlights.Is_Empty
        or else Item.Armed_Menu /= 0
        or else Item.Armed_Item /= 0
      then
         Invalidate_Presentation (Item);
         Clear_Open_State (Item);
      end if;
   end Close;

   procedure Set_Enabled (Item : in out Model; Enabled : Boolean) is
   begin
      if Item.Enabled = Enabled then
         return;
      end if;
      Invalidate_Presentation (Item);
      Item.Enabled := Enabled;
      if not Enabled then
         Clear_Open_State (Item);
      end if;
   end Set_Enabled;

   procedure Set_Menu_Enabled
     (Item : in out Model; Id : Menu_Id; Enabled : Boolean := True)
   is
      Index : constant Natural := Find_Menu (Item.Menus, Id);
      Value : Menu_Definition;
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Value := Item.Menus.Element (Index - 1);
      if Value.Enabled = Enabled then
         return;
      end if;
      Invalidate_Presentation (Item);
      Value.Enabled := Enabled;
      Item.Menus.Replace_Element (Index - 1, Value);
      if not Enabled then
         if Item.Focused = Index then
            Item.Focused := First_Top (Item);
         end if;
         Clear_Open_State (Item);
      end if;
   end Set_Menu_Enabled;

   procedure Set_Item_Enabled
     (Item : in out Model; Id : Item_Id; Enabled : Boolean := True)
   is
      Index : constant Natural := Find_Item (Item.Items, Id);
      Value : Stored_Item;
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Value := Item.Items.Element (Index - 1);
      if Value.Kind = Separator_Item and then Enabled then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      if Value.Enabled = Enabled and then Item.Armed_Item = 0 then
         return;
      end if;
      Invalidate_Presentation (Item);
      Value.Enabled := Enabled;
      Item.Items.Replace_Element (Index - 1, Value);
      if not Enabled and then not Item.Highlights.Is_Empty then
         for Depth in 0 .. Natural (Item.Highlights.Length) - 1 loop
            if Item.Highlights.Element (Depth) = Index then
               Item.Highlights.Replace_Element
                 (Depth,
                  First_Item
                    (Item, Item.Open_Menus.Element (Depth), True));
               while Natural (Item.Open_Menus.Length) > Depth + 1 loop
                  Item.Open_Menus.Delete_Last;
                  Item.Highlights.Delete_Last;
               end loop;
               exit;
            end if;
         end loop;
      end if;
      Item.Armed_Item := 0;
   end Set_Item_Enabled;

   function Is_Open (Item : Model) return Boolean is
     (not Item.Open_Menus.Is_Empty);
   function Open_Depth (Item : Model) return Natural is
     (Natural (Item.Open_Menus.Length));

   procedure Open_Top
     (Item : in out Model; Index : Natural; Changed : out Boolean)
   is
      Valid : constant Boolean := Item.Enabled
        and then Index > 0
        and then Item.Menus.Element (Index - 1).Top_Level
        and then Item.Menus.Element (Index - 1).Enabled;
      Highlight : constant Natural :=
        (if Valid then First_Item (Item, Index, True) else 0);
   begin
      Changed :=
        (if Valid then
           Item.Focused /= Index
           or else Natural (Item.Open_Menus.Length) /= 1
           or else Item.Open_Menus.First_Element /= Index
           or else Natural (Item.Highlights.Length) /= 1
           or else Item.Highlights.First_Element /= Highlight
         else not Item.Open_Menus.Is_Empty
           or else not Item.Highlights.Is_Empty);
      if not Changed then
         return;
      end if;
      Invalidate_Presentation (Item);
      Item.Open_Menus.Clear;
      Item.Highlights.Clear;
      if Valid then
         Item.Focused := Index;
         Item.Open_Menus.Append (Index);
         Item.Highlights.Append (Highlight);
      end if;
   end Open_Top;

   procedure Open_Menu (Item : in out Model; Id : Menu_Id) is
      Index : constant Natural := Find_Menu (Item.Menus, Id);
      Changed : Boolean;
   begin
      if Index = 0
        or else not Item.Menus.Element (Index - 1).Top_Level
      then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Open_Top (Item, Index, Changed);
   end Open_Menu;

   function Dismiss (Item : in out Model) return Update_Result is
      Was_Open : constant Boolean := Is_Open (Item);
      Was_Capturing : constant Boolean := Item.Capturing;
   begin
      Close (Item);
      if Was_Capturing then
         Invalidate_Presentation (Item);
      end if;
      Item.Capturing := False;
      return
        (Kind  => No_Result,
         Event =>
           (Handled => Was_Open or else Was_Capturing,
            Changed => Was_Open,
            Capture =>
              (if Was_Capturing
               then Flyology_TUI.Components.Interactions.Release_Capture
               else Flyology_TUI.Components.Interactions.No_Capture_Change),
            others => <>));
   end Dismiss;

   function Has_Focused_Menu (Item : Model) return Boolean is
     (Item.Focused > 0);
   function Focused_Menu (Item : Model) return Menu_Id is
     (Item.Menus.Element (Item.Focused - 1).Id);
   function Has_Highlighted_Item (Item : Model) return Boolean is
     (not Item.Highlights.Is_Empty
      and then Item.Highlights.Last_Element > 0);
   function Highlighted_Item (Item : Model) return Item_Id is
     (Item.Items.Element (Item.Highlights.Last_Element - 1).Id);

   function Is_Checked (Item : Model; Id : Item_Id) return Boolean is
      Index : constant Natural := Find_Item (Item.Items, Id);
   begin
      return Item.Items.Element (Index - 1).Kind in Check_Item | Radio_Item
        and then Item.Item_State.Element (Index - 1);
   end Is_Checked;

   procedure Set_Checked
     (Item : in out Model; Id : Item_Id; Checked : Boolean := True)
   is
      Index : constant Natural := Find_Item (Item.Items, Id);
      Definition : Stored_Item;
   begin
      if Index = 0 then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      Definition := Item.Items.Element (Index - 1);
      if Definition.Kind not in Check_Item | Radio_Item then
         raise Flyology_TUI.Components.Structure_Error;
      end if;
      declare
         State_Changes : Boolean := Item.Armed_Item /= 0;
      begin
         if Definition.Kind = Radio_Item and then Checked then
            for Position in 1 .. Natural (Item.Items.Length) loop
               declare
                  Other : constant Stored_Item :=
                    Item.Items.Element (Position - 1);
               begin
                  if Other.Kind = Radio_Item
                    and then Other.Menu = Definition.Menu
                    and then Other.Group = Definition.Group
                    and then Item.Item_State.Element (Position - 1) /=
                      (Position = Index)
                  then
                     State_Changes := True;
                  end if;
               end;
            end loop;
         elsif Item.Item_State.Element (Index - 1) /= Checked then
            State_Changes := True;
         end if;
         if not State_Changes then
            return;
         end if;
         Invalidate_Presentation (Item);
      end;
      if Definition.Kind = Radio_Item and then Checked then
         for Position in 1 .. Natural (Item.Items.Length) loop
            declare
               Other : constant Stored_Item :=
                 Item.Items.Element (Position - 1);
            begin
               if Other.Kind = Radio_Item
                 and then Other.Menu = Definition.Menu
                 and then Other.Group = Definition.Group
               then
                  Item.Item_State.Replace_Element (Position - 1, False);
               end if;
            end;
         end loop;
      end if;
      Item.Item_State.Replace_Element (Index - 1, Checked);
      Item.Armed_Item := 0;
   end Set_Checked;

   function Interaction
     (Item : Update_Result)
      return Flyology_TUI.Components.Interactions.Update_Result is
     (Item.Event);

   function Activated_Menu (Item : Update_Result) return Menu_Id is
     (case Item.Kind is
         when Action_Activated => Item.Action_Menu,
         when Check_Changed    => Item.Check_Menu,
         when Radio_Changed    => Item.Radio_Menu,
         when No_Result        => raise Program_Error);

   function Activated_Item (Item : Update_Result) return Item_Id is
     (case Item.Kind is
         when Action_Activated => Item.Action_Id,
         when Check_Changed    => Item.Check_Id,
         when Radio_Changed    => Item.Radio_Id,
         when No_Result        => raise Program_Error);

   function Checked_Value (Item : Update_Result) return Boolean is
     (Item.Is_Checked);
   function Radio_Group (Item : Update_Result) return Item_Id is
     (Item.Group_Id);

   procedure Open_Child
     (Item         : in out Model;
      Parent_Item  : Natural;
      Parent_Depth : Positive;
      Changed      : out Boolean)
   is
      Definition : constant Stored_Item :=
        Item.Items.Element (Parent_Item - 1);
      Child : constant Natural :=
        (if Definition.Kind = Submenu_Item
         then Find_Menu (Item.Menus, Definition.Child) else 0);
   begin
      Changed := False;
      if Child = 0
        or else not Item.Menus.Element (Child - 1).Enabled
        or else Parent_Depth >= Maximum_Depth
      then
         return;
      end if;
      declare
         Highlight : constant Natural := First_Item (Item, Child, True);
      begin
         Changed := Natural (Item.Open_Menus.Length) /= Parent_Depth + 1
           or else Item.Open_Menus.Element (Parent_Depth) /= Child
           or else Natural (Item.Highlights.Length) /= Parent_Depth + 1
           or else Item.Highlights.Element (Parent_Depth) /= Highlight;
         if not Changed then
            return;
         end if;
         Invalidate_Presentation (Item);
      end;
      while Natural (Item.Open_Menus.Length) > Parent_Depth loop
         Item.Open_Menus.Delete_Last;
         Item.Highlights.Delete_Last;
      end loop;
      if Natural (Item.Open_Menus.Length) = Parent_Depth then
         Item.Open_Menus.Append (Child);
         Item.Highlights.Append (First_Item (Item, Child, True));
      else
         Item.Open_Menus.Replace_Element (Parent_Depth, Child);
         Item.Highlights.Replace_Element
           (Parent_Depth, First_Item (Item, Child, True));
      end if;
   end Open_Child;

   function Activate_Index
     (Item : in out Model; Index : Natural; Depth : Positive)
      return Update_Result
   is
      Definition : constant Stored_Item := Item.Items.Element (Index - 1);
      Changed : Boolean;
   begin
      if not Is_Selectable (Item, Index) then
         return
           (Kind => No_Result,
            Event => (Handled => True, others => <>));
      end if;
      case Definition.Kind is
         when Separator_Item =>
            return
              (Kind => No_Result,
               Event => (Handled => True, others => <>));
         when Submenu_Item =>
            declare
               Changed : Boolean;
            begin
               Open_Child (Item, Index, Depth, Changed);
               return
                 (Kind => No_Result,
                  Event =>
                    (Handled => True,
                     Changed => Changed,
                     others => <>));
            end;
         when Action_Item =>
            Close (Item);
            return
              (Kind        => Action_Activated,
               Event       =>
                 (Handled => True, Activated => True, Changed => True,
                  others => <>),
               Action_Menu => Definition.Menu,
               Action_Id   => Definition.Id);
         when Check_Item =>
            Changed := not Item.Item_State.Element (Index - 1);
            Item.Item_State.Replace_Element (Index - 1, Changed);
            Close (Item);
            return
              (Kind       => Check_Changed,
               Event      =>
                 (Handled => True, Activated => True, Changed => True,
                  others => <>),
               Check_Menu => Definition.Menu,
               Check_Id   => Definition.Id,
               Is_Checked => Changed);
         when Radio_Item =>
            Changed := not Item.Item_State.Element (Index - 1);
            Set_Checked (Item, Definition.Id, True);
            Close (Item);
            return
              (Kind       => Radio_Changed,
               Event      =>
                 (Handled => True, Activated => True, Changed => True,
                  others => <>),
               Radio_Menu => Definition.Menu,
               Radio_Id   => Definition.Id,
               Group_Id   => Definition.Group);
      end case;
   end Activate_Index;

   function Plain
     (Event : Flyology_TUI.Components.Interactions.Update_Result)
      return Update_Result is
     ((Kind => No_Result, Event => Event));

   function Same_Mnemonic
     (Left, Right : Wide_Wide_Character) return Boolean
   is
      function Fold (Value : Wide_Wide_Character) return Wide_Wide_Character is
        (if Value in 'A' .. 'Z'
         then Wide_Wide_Character'Val
           (Wide_Wide_Character'Pos (Value) +
            Wide_Wide_Character'Pos ('a') - Wide_Wide_Character'Pos ('A'))
         else Value);
   begin
      return Fold (Left) = Fold (Right);
   end Same_Mnemonic;

   procedure Switch_Top
     (Item      : in out Model;
      Direction : Integer;
      Keep_Open : Boolean;
      Changed   : out Boolean)
   is
      Before : constant Natural := Item.Focused;
      Target : Natural;
   begin
      Changed := False;
      if Item.Focused = 0 then
         Target := First_Top (Item);
      else
         Target := Next_Top (Item, Item.Focused, Direction);
         if Target = Item.Focused then
            Target :=
              (if Direction < 0 then Last_Top (Item) else First_Top (Item));
         end if;
      end if;
      if Target > 0 then
         if Keep_Open then
            Open_Top (Item, Target, Changed);
         elsif Before /= Target then
            Invalidate_Presentation (Item);
            Item.Focused := Target;
            Item.Armed_Menu := 0;
            Changed := True;
         end if;
      end if;
   end Switch_Top;

   function Handle_Mnemonic
     (Item : in out Model; Value : Wide_Wide_Character)
      return Update_Result
   is
   begin
      if Is_Open (Item) then
         declare
            Menu_Index : constant Natural := Item.Open_Menus.Last_Element;
         begin
            for Index in 1 .. Natural (Item.Items.Length) loop
               declare
                  Definition : constant Stored_Item :=
                    Item.Items.Element (Index - 1);
               begin
                  if Definition.Menu = Item.Menus.Element
                       (Menu_Index - 1).Id
                    and then Is_Selectable (Item, Index)
                    and then Same_Mnemonic
                      (Value, Item_Mnemonic (Definition.Id))
                  then
                     if Item.Highlights.Last_Element /= Index then
                        Invalidate_Presentation (Item);
                     end if;
                     Item.Highlights.Replace_Element
                       (Natural (Item.Highlights.Length) - 1, Index);
                     return Activate_Index
                       (Item, Index, Positive (Item.Open_Menus.Length));
                  end if;
               end;
            end loop;
         end;
      end if;
      for Index in 1 .. Natural (Item.Menus.Length) loop
         declare
            Definition : constant Menu_Definition :=
              Item.Menus.Element (Index - 1);
         begin
            if Definition.Top_Level
              and then Definition.Enabled
              and then Same_Mnemonic
                (Value, Menu_Mnemonic (Definition.Id))
            then
               declare
                  Changed : Boolean;
               begin
                  Open_Top (Item, Index, Changed);
                  return Plain
                    ((Handled => True, Focus_Requested => True,
                      Changed => Changed, others => <>));
               end;
            end if;
         end;
      end loop;
      return Plain (Flyology_TUI.Components.Interactions.Ignored);
   end Handle_Mnemonic;

   function Handle
     (Item : in out Model; Event : Flyology_TUI.Events.Terminal_Event)
      return Update_Result
   is
      Before : Natural;
      Target : Natural;
   begin
      if not Item.Enabled
        or else Event.Kind /= Flyology_TUI.Events.Key_Press
        or else First_Top (Item) = 0
      then
         return Plain (Flyology_TUI.Components.Interactions.Ignored);
      end if;

      if Event.Key.Kind = Flyology_TUI.Events.Text_Key then
         declare
            Value : constant Wide_Wide_String :=
              Text.To_Wide_Wide_String (Event.Key.Value);
         begin
            if Value'Length = 1 and then Value (Value'First) /= ' ' then
               declare
                  Result : constant Update_Result :=
                    Handle_Mnemonic (Item, Value (Value'First));
               begin
                  if Result.Event.Handled then
                     return Result;
                  end if;
               end;
            end if;
         end;
      end if;

      if Event.Key.Kind = Flyology_TUI.Events.Escape_Key then
         if not Is_Open (Item) then
            return Plain (Flyology_TUI.Components.Interactions.Ignored);
         elsif Item.Open_Menus.Length > 1 then
            Invalidate_Presentation (Item);
            Item.Open_Menus.Delete_Last;
            Item.Highlights.Delete_Last;
            return Plain
              ((Handled => True, Changed => True, others => <>));
         else
            Close (Item);
            return Plain
              ((Handled => True, Changed => True, others => <>));
         end if;
      end if;

      if not Is_Open (Item) then
         if Item.Focused = 0 then
            Invalidate_Presentation (Item);
            Item.Focused := First_Top (Item);
         end if;
         case Event.Key.Kind is
            when Flyology_TUI.Events.Arrow_Left_Key =>
               declare
                  Changed : Boolean;
               begin
                  Switch_Top (Item, -1, False, Changed);
                  return Plain
                    ((Handled => True, Focus_Requested => True,
                      Changed => Changed, others => <>));
               end;
            when Flyology_TUI.Events.Arrow_Right_Key =>
               declare
                  Changed : Boolean;
               begin
                  Switch_Top (Item, 1, False, Changed);
                  return Plain
                    ((Handled => True, Focus_Requested => True,
                      Changed => Changed, others => <>));
               end;
            when Flyology_TUI.Events.Home_Key =>
               Before := Item.Focused;
               if Before /= First_Top (Item) then
                  Invalidate_Presentation (Item);
                  Item.Focused := First_Top (Item);
               end if;
               return Plain
                 ((Handled => True, Focus_Requested => True,
                   Changed => Before /= Item.Focused, others => <>));
            when Flyology_TUI.Events.End_Key =>
               Before := Item.Focused;
               if Before /= Last_Top (Item) then
                  Invalidate_Presentation (Item);
                  Item.Focused := Last_Top (Item);
               end if;
               return Plain
                 ((Handled => True, Focus_Requested => True,
                   Changed => Before /= Item.Focused, others => <>));
            when Flyology_TUI.Events.Arrow_Down_Key
               | Flyology_TUI.Events.Enter_Key =>
               declare
                  Changed : Boolean;
               begin
                  Open_Top (Item, Item.Focused, Changed);
                  return Plain
                    ((Handled => True, Focus_Requested => True,
                      Changed => Changed, others => <>));
               end;
            when Flyology_TUI.Events.Text_Key =>
               if Text.To_Wide_Wide_String (Event.Key.Value) = " " then
                  declare
                     Changed : Boolean;
                  begin
                     Open_Top (Item, Item.Focused, Changed);
                     return Plain
                       ((Handled => True, Focus_Requested => True,
                         Changed => Changed, others => <>));
                  end;
               end if;
            when others => null;
         end case;
         return Plain (Flyology_TUI.Components.Interactions.Ignored);
      end if;

      declare
         Depth : constant Positive := Positive (Item.Open_Menus.Length);
         Menu_Index : constant Natural := Item.Open_Menus.Last_Element;
         Highlight : constant Natural := Item.Highlights.Last_Element;
      begin
         case Event.Key.Kind is
            when Flyology_TUI.Events.Arrow_Up_Key =>
               Target :=
                 (if Highlight = 0 then Last_Item (Item, Menu_Index, True)
                  else Next_Item (Item, Menu_Index, Highlight, -1));
               if Target = Highlight and then Highlight > 0 then
                  Target := Last_Item (Item, Menu_Index, True);
               end if;
               if Target /= Highlight then
                  Invalidate_Presentation (Item);
                  Item.Highlights.Replace_Element (Depth - 1, Target);
               end if;
               while Natural (Item.Open_Menus.Length) > Depth loop
                  Item.Open_Menus.Delete_Last;
                  Item.Highlights.Delete_Last;
               end loop;
               return Plain
                 ((Handled => True, Changed => Target /= Highlight,
                   others => <>));
            when Flyology_TUI.Events.Arrow_Down_Key =>
               Target :=
                 (if Highlight = 0 then First_Item (Item, Menu_Index, True)
                  else Next_Item (Item, Menu_Index, Highlight, 1));
               if Target = Highlight and then Highlight > 0 then
                  Target := First_Item (Item, Menu_Index, True);
               end if;
               if Target /= Highlight then
                  Invalidate_Presentation (Item);
                  Item.Highlights.Replace_Element (Depth - 1, Target);
               end if;
               return Plain
                 ((Handled => True, Changed => Target /= Highlight,
                   others => <>));
            when Flyology_TUI.Events.Home_Key =>
               Target := First_Item (Item, Menu_Index, True);
               if Target /= Highlight then
                  Invalidate_Presentation (Item);
                  Item.Highlights.Replace_Element (Depth - 1, Target);
               end if;
               return Plain
                 ((Handled => True, Changed => Target /= Highlight,
                   others => <>));
            when Flyology_TUI.Events.End_Key =>
               Target := Last_Item (Item, Menu_Index, True);
               if Target /= Highlight then
                  Invalidate_Presentation (Item);
                  Item.Highlights.Replace_Element (Depth - 1, Target);
               end if;
               return Plain
                 ((Handled => True, Changed => Target /= Highlight,
                   others => <>));
            when Flyology_TUI.Events.Arrow_Left_Key =>
               if Depth > 1 then
                  Invalidate_Presentation (Item);
                  Item.Open_Menus.Delete_Last;
                  Item.Highlights.Delete_Last;
                  return Plain
                    ((Handled => True, Changed => True, others => <>));
               else
                  declare
                     Changed : Boolean;
                  begin
                     Switch_Top (Item, -1, True, Changed);
                     return Plain
                       ((Handled => True, Changed => Changed, others => <>));
                  end;
               end if;
            when Flyology_TUI.Events.Arrow_Right_Key =>
               declare
                  Changed : Boolean := False;
               begin
                  if Highlight > 0
                    and then Item.Items.Element (Highlight - 1).Kind =
                      Submenu_Item
                  then
                     Open_Child (Item, Highlight, Depth, Changed);
                  elsif Depth = 1 then
                     Switch_Top (Item, 1, True, Changed);
                  end if;
                  return Plain
                    ((Handled => True,
                      Changed => Changed,
                      others => <>));
               end;
            when Flyology_TUI.Events.Enter_Key =>
               if Highlight > 0 then
                  return Activate_Index (Item, Highlight, Depth);
               end if;
            when Flyology_TUI.Events.Text_Key =>
               if Text.To_Wide_Wide_String (Event.Key.Value) = " "
                 and then Highlight > 0
               then
                  return Activate_Index (Item, Highlight, Depth);
               end if;
            when others => null;
         end case;
      end;
      return Plain (Flyology_TUI.Components.Interactions.Ignored);
   end Handle;

   function Symbol (Code : Natural) return Wide_Wide_String is
     (Wide_Wide_String'(1 => Wide_Wide_Character'Val (Code)));

   function Capped_Add
     (Left, Right, Limit : Natural) return Natural is
     (if Left >= Limit or else Right >= Limit - Left
      then Limit else Left + Right);

   function Saturated_Add
     (Left : Integer; Right : Natural) return Integer
   is
      Value : constant Long_Long_Integer :=
        Long_Long_Integer (Left) + Long_Long_Integer (Right);
   begin
      if Value > Long_Long_Integer (Integer'Last) then
         return Integer'Last;
      elsif Value < Long_Long_Integer (Integer'First) then
         return Integer'First;
      else
         return Integer (Value);
      end if;
   end Saturated_Add;

   function Clip
     (X, Y          : Integer;
      Region_Width  : Natural;
      Region_Height : Natural;
      Width, Height : Natural) return Flyology_TUI.Geometry.Rectangle
   is
      subtype Wide is Long_Long_Integer;
      Left   : constant Wide := Wide'Max (0, Wide (X));
      Top    : constant Wide := Wide'Max (0, Wide (Y));
      Right  : constant Wide := Wide'Min
        (Wide (Width), Wide (X) + Wide (Region_Width));
      Bottom : constant Wide := Wide'Min
        (Wide (Height), Wide (Y) + Wide (Region_Height));
   begin
      if Right <= Left or else Bottom <= Top then
         return
           (X      => Integer (Wide'Min (Wide (Width), Left)),
            Y      => Integer (Wide'Min (Wide (Height), Top)),
            Width  => 0,
            Height => 0);
      end if;
      return
        (X      => Integer (Left),
         Y      => Integer (Top),
         Width  => Natural (Right - Left),
         Height => Natural (Bottom - Top));
   end Clip;

   function Header_Width
     (Id : Menu_Id; Limit : Natural) return Natural
   is
      Label_Width : constant Natural :=
        Natural'Min (Limit, Flyology_TUI.Glyphs.Width_Of (Menu_Label (Id)));
   begin
      return Capped_Add (Label_Width, 2, Limit);
   end Header_Width;

   function Item_Total (Item : Model; Menu_Index : Natural) return Natural is
      Result : Natural := 0;
   begin
      for Definition of Item.Items loop
         if Definition.Menu = Item.Menus.Element (Menu_Index - 1).Id then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Item_Total;

   function Popup_Width
     (Item : Model; Menu_Index : Natural; Limit : Natural) return Natural
   is
      Result : Natural := Natural'Min (4, Limit);
   begin
      for Definition of Item.Items loop
         if Definition.Menu = Item.Menus.Element (Menu_Index - 1).Id then
            declare
               Label_Width : constant Natural := Natural'Min
                 (Limit,
                  Flyology_TUI.Glyphs.Width_Of (Item_Label (Definition.Id)));
               Shortcut_Width : constant Natural := Natural'Min
                 (Limit,
                  Flyology_TUI.Glyphs.Width_Of
                    (Shortcut_Label (Definition.Id)));
               Required : Natural := Capped_Add (3, Label_Width, Limit);
            begin
               Required := Capped_Add (Required, Shortcut_Width, Limit);
               Required := Capped_Add (Required, 4, Limit);
               Result := Natural'Max (Result, Required);
            end;
         end if;
      end loop;
      return Result;
   end Popup_Width;

   function Place
     (Preferred : Long_Long_Integer;
      Span      : Natural;
      Limit     : Natural) return Integer
   is
      Maximum : constant Long_Long_Integer :=
        Long_Long_Integer (Limit - Natural'Min (Span, Limit));
   begin
      if Preferred <= 0 then
         return 0;
      elsif Preferred >= Maximum then
         return Integer (Maximum);
      else
         return Integer (Preferred);
      end if;
   end Place;

   procedure Draw_Border
     (Target : in out Flyology_TUI.Surfaces.Surface;
      Look   : Appearance) is
   begin
      if Target.Width = 0 or else Target.Height = 0 then
         return;
      end if;
      if Target.Width = 1 or else Target.Height = 1 then
         for Y in 0 .. Target.Height - 1 loop
            for X in 0 .. Target.Width - 1 loop
               Target.Put (X, Y, Symbol (16#2500#), Look.Separator);
            end loop;
         end loop;
         return;
      end if;
      Target.Put (0, 0, Symbol (16#250C#), Look.Separator);
      Target.Put (Target.Width - 1, 0, Symbol (16#2510#), Look.Separator);
      Target.Put (0, Target.Height - 1, Symbol (16#2514#), Look.Separator);
      Target.Put
        (Target.Width - 1, Target.Height - 1,
         Symbol (16#2518#), Look.Separator);
      if Target.Width > 2 then
         for X in 1 .. Target.Width - 2 loop
            Target.Put (X, 0, Symbol (16#2500#), Look.Separator);
            Target.Put
              (X, Target.Height - 1, Symbol (16#2500#), Look.Separator);
         end loop;
      end if;
      if Target.Height > 2 then
         for Y in 1 .. Target.Height - 2 loop
            Target.Put (0, Y, Symbol (16#2502#), Look.Separator);
            Target.Put
              (Target.Width - 1, Y, Symbol (16#2502#), Look.Separator);
         end loop;
      end if;
   end Draw_Border;

   function Present
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Look      : Appearance;
      Has_Focus : Boolean := False) return Presentation
   is
      Result : Presentation;
      Bar : Flyology_TUI.Surfaces.Surface;
      Offset : Natural := 0;
      type Coordinate_Array is array (Positive range <>) of Integer;
      type Span_Array is array (Positive range <>) of Natural;
      Popup_X : Coordinate_Array (1 .. Maximum_Depth) := (others => 0);
      Popup_Y : Coordinate_Array (1 .. Maximum_Depth) := (others => 0);
      Popup_Span : Span_Array (1 .. Maximum_Depth) := (others => 0);

      function Top_Offset (Menu_Index : Natural) return Natural is
         Position : Natural := 0;
      begin
         for Index in 1 .. Natural (Item.Menus.Length) loop
            if Item.Menus.Element (Index - 1).Top_Level then
               if Index = Menu_Index then
                  return Position;
               end if;
               Position := Capped_Add
                 (Position,
                  Header_Width (Item.Menus.Element (Index - 1).Id, Width),
                  Width);
            end if;
         end loop;
         return Position;
      end Top_Offset;

      function Ordinal
        (Menu_Index : Natural; Item_Index : Natural) return Natural
      is
         Result : Natural := 0;
      begin
         for Index in 1 .. Item_Index loop
            if Item.Items.Element (Index - 1).Menu =
                 Item.Menus.Element (Menu_Index - 1).Id
            then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Ordinal;
   begin
      if Width /= 0 and then Height > Natural'Last / Width then
         raise Flyology_TUI.Components.Capacity_Error;
      end if;
      Result.Revision := Item.Presentation_Revision;
      Result.Frame_Value := Flyology_TUI.Surfaces.Create (Width, Height);
      Result.Bar_Value := Clip (X, Y, Width, 1, Width, Height);
      if Width = 0 or else Height = 0 then
         return Result;
      end if;

      Bar := Flyology_TUI.Surfaces.Create (Width, 1, Look.Bar);
      if not Item.Menus.Is_Empty then
         for Index in 1 .. Natural (Item.Menus.Length) loop
            declare
               Definition : constant Menu_Definition :=
                 Item.Menus.Element (Index - 1);
            begin
               if Definition.Top_Level and then Offset < Width then
                  declare
                     Span : constant Natural := Header_Width
                       (Definition.Id, Width - Offset);
                     Active : constant Boolean :=
                       Item.Focused = Index
                       or else
                         (not Item.Open_Menus.Is_Empty
                          and then Item.Open_Menus.First_Element = Index);
                     Style : constant Flyology_TUI.Styles.Style :=
                       (if not Item.Enabled or else not Definition.Enabled
                        then Look.Disabled
                        elsif Active and then Has_Focus then Look.Focused
                        elsif Active then Look.Highlighted
                        else Look.Bar);
                     Header : Flyology_TUI.Surfaces.Surface :=
                       Flyology_TUI.Surfaces.Create (Span, 1, Style);
                     Region : constant Flyology_TUI.Geometry.Rectangle :=
                       Clip
                         (Saturated_Add (X, Offset),
                          Y, Span, 1, Width, Height);
                  begin
                     Header.Write
                       (0, 0, " " & Menu_Label (Definition.Id), Style);
                     Bar.Overlay_Clipped (Header, Integer (Offset), 0);
                     if Region.Width > 0 and then Region.Height > 0 then
                        Result.Menus.Append
                          (Menu_Hit'
                             (Id => Definition.Id, Index => Index,
                              Depth => 0, Region => Region));
                     end if;
                     Offset := Capped_Add (Offset, Span, Width);
                  end;
               end if;
            end;
         end loop;
      end if;
      Result.Frame_Value.Overlay_Clipped (Bar, X, Y);

      if Item.Open_Menus.Is_Empty then
         return Result;
      end if;
      for Depth in 1 .. Natural (Item.Open_Menus.Length) loop
         declare
            Menu_Index : constant Natural :=
              Item.Open_Menus.Element (Depth - 1);
            Item_Count : constant Natural := Item_Total (Item, Menu_Index);
            Span : constant Natural := Popup_Width (Item, Menu_Index, Width);
            Rows : constant Natural := Natural'Min
              (Height, Capped_Add (Item_Count, 2, Height));
            Preferred_X : Long_Long_Integer;
            Preferred_Y : Long_Long_Integer;
         begin
            exit when Span = 0 or else Rows = 0;
            if Depth = 1 then
               Preferred_X := Long_Long_Integer (X)
                 + Long_Long_Integer (Top_Offset (Menu_Index));
               Preferred_Y := Long_Long_Integer (Y) + 1;
            else
               declare
                  Parent_Highlight : constant Natural :=
                    Item.Highlights.Element (Depth - 2);
                  Parent_Menu : constant Natural :=
                    Item.Open_Menus.Element (Depth - 2);
                  Row : constant Natural :=
                    Ordinal (Parent_Menu, Parent_Highlight);
                  Right : constant Long_Long_Integer :=
                    Long_Long_Integer (Popup_X (Depth - 1))
                    + Long_Long_Integer (Popup_Span (Depth - 1));
                  Left : constant Long_Long_Integer :=
                    Long_Long_Integer (Popup_X (Depth - 1))
                    - Long_Long_Integer (Span);
               begin
                  Preferred_X :=
                    (if Right + Long_Long_Integer (Span) <=
                          Long_Long_Integer (Width)
                     then Right else Left);
                  Preferred_Y := Long_Long_Integer (Popup_Y (Depth - 1))
                    + Long_Long_Integer (Row);
               end;
            end if;
            Popup_X (Depth) := Place (Preferred_X, Span, Width);
            Popup_Y (Depth) := Place (Preferred_Y, Rows, Height);
            Popup_Span (Depth) := Span;
            declare
               Popup : Flyology_TUI.Surfaces.Surface :=
                 Flyology_TUI.Surfaces.Create (Span, Rows, Look.Menu);
               Menu_Region_Value : constant Flyology_TUI.Geometry.Rectangle :=
                 Clip
                   (Popup_X (Depth), Popup_Y (Depth), Span, Rows,
                    Width, Height);
               Row_Number : Natural := 0;
            begin
               Draw_Border (Popup, Look);
               if Menu_Region_Value.Width > 0
                 and then Menu_Region_Value.Height > 0
               then
                  Result.Menus.Append
                    (Menu_Hit'
                       (Id => Item.Menus.Element (Menu_Index - 1).Id,
                        Index => Menu_Index, Depth => Depth,
                        Region => Menu_Region_Value));
               end if;
               for Index in 1 .. Natural (Item.Items.Length) loop
                  declare
                     Definition : constant Stored_Item :=
                       Item.Items.Element (Index - 1);
                  begin
                     if Definition.Menu =
                       Item.Menus.Element (Menu_Index - 1).Id
                     then
                        Row_Number := Row_Number + 1;
                        if Span > 2
                          and then Rows > 1
                          and then Row_Number < Rows - 1
                        then
                           declare
                              Inner : constant Natural := Span - 2;
                              Highlighted : constant Boolean :=
                                Item.Highlights.Element (Depth - 1) = Index;
                              Style : constant Flyology_TUI.Styles.Style :=
                                (if not Item.Enabled
                                   or else not Definition.Enabled
                                 then Look.Disabled
                                 elsif Highlighted then Look.Highlighted
                                 else Look.Menu);
                              Row : Flyology_TUI.Surfaces.Surface :=
                                Flyology_TUI.Surfaces.Create (Inner, 1, Style);
                              Shortcut : constant Wide_Wide_String :=
                                Shortcut_Label (Definition.Id);
                              Shortcut_Width : constant Natural :=
                                Flyology_TUI.Glyphs.Width_Of (Shortcut);
                              Region : constant
                                Flyology_TUI.Geometry.Rectangle :=
                                Clip
                                  (Popup_X (Depth) + 1,
                                   Popup_Y (Depth) + Integer (Row_Number),
                                   Inner, 1, Width, Height);
                           begin
                              if Definition.Kind = Separator_Item then
                                 for Column in 0 .. Inner - 1 loop
                                    Row.Put
                                      (Column, 0, Symbol (16#2500#),
                                       Look.Separator);
                                 end loop;
                              else
                                 if Definition.Kind = Check_Item
                                   and then Item.Item_State.Element (Index - 1)
                                 then
                                    Row.Write (0, 0, "[x]", Look.Marker);
                                 elsif Definition.Kind = Radio_Item
                                   and then Item.Item_State.Element (Index - 1)
                                 then
                                    Row.Write (0, 0, "(*)", Look.Marker);
                                 end if;
                                 if Inner > 3 then
                                    Row.Write
                                      (3, 0, Item_Label (Definition.Id),
                                       Style);
                                 end if;
                                 if Shortcut'Length > 0
                                   and then Inner > 1
                                   and then Shortcut_Width < Inner - 1
                                 then
                                    Row.Write
                                      (Inner - Shortcut_Width - 1, 0,
                                       Shortcut, Look.Shortcut);
                                 end if;
                                 if Definition.Kind = Submenu_Item
                                   and then Inner > 0
                                 then
                                    Row.Put
                                      (Inner - 1, 0, Symbol (16#25B8#), Style);
                                 end if;
                              end if;
                              Popup.Overlay_Clipped
                                (Row, 1, Integer (Row_Number));
                              if Region.Width > 0
                                and then Region.Height > 0
                              then
                                 Result.Items.Append
                                   (Item_Hit'
                                      (Id => Definition.Id, Index => Index,
                                       Depth => Depth, Region => Region));
                              end if;
                           end;
                        end if;
                     end if;
                  end;
               end loop;
               Result.Frame_Value.Overlay_Clipped
                 (Popup, Popup_X (Depth), Popup_Y (Depth));
            end;
         end;
      end loop;
      return Result;
   end Present;

   function Present
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False) return Presentation is
     (Present (Item, Width, Height, X, Y, From_Theme (Theme), Has_Focus));

   function Frame
     (Item : Presentation) return Flyology_TUI.Surfaces.Surface is
     (Item.Frame_Value);
   function Bar_Region
     (Item : Presentation) return Flyology_TUI.Geometry.Rectangle is
     (Item.Bar_Value);

   function Has_Menu_Region
     (Item : Presentation; Id : Menu_Id) return Boolean is
   begin
      for Hit of Item.Menus loop
         if Hit.Id = Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Menu_Region;

   function Menu_Region
     (Item : Presentation; Id : Menu_Id)
      return Flyology_TUI.Geometry.Rectangle is
   begin
      for Hit of Item.Menus loop
         if Hit.Id = Id then
            return Hit.Region;
         end if;
      end loop;
      raise Program_Error;
   end Menu_Region;

   function Has_Item_Region
     (Item : Presentation; Id : Item_Id) return Boolean is
   begin
      for Hit of Item.Items loop
         if Hit.Id = Id then
            return True;
         end if;
      end loop;
      return False;
   end Has_Item_Region;

   function Item_Region
     (Item : Presentation; Id : Item_Id)
      return Flyology_TUI.Geometry.Rectangle is
   begin
      for Hit of Item.Items loop
         if Hit.Id = Id then
            return Hit.Region;
         end if;
      end loop;
      raise Program_Error;
   end Item_Region;

   function Render
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Look      : Appearance;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Frame (Present (Item, Width, Height, X, Y, Look, Has_Focus)));

   function Render
     (Item      : Model;
      Width     : Natural;
      Height    : Natural;
      X         : Integer;
      Y         : Integer;
      Theme     : Flyology_TUI.Themes.Theme;
      Has_Focus : Boolean := False)
      return Flyology_TUI.Surfaces.Surface is
     (Frame (Present (Item, Width, Height, X, Y, Theme, Has_Focus)));

   procedure Hit_Topmost
     (Layout : Presentation;
      Point  : Flyology_TUI.Geometry.Point;
      Menu_Index : out Natural;
      Item_Index : out Natural;
      Depth      : out Positive;
      Overlay    : out Boolean)
   is
   begin
      Menu_Index := 0;
      Item_Index := 0;
      Depth := 1;
      Overlay := False;
      if not Layout.Menus.Is_Empty then
         for Position in reverse 0 .. Natural (Layout.Menus.Length) - 1 loop
            declare
               Hit : constant Menu_Hit := Layout.Menus.Element (Position);
            begin
               if Hit.Depth > 0
                 and then Flyology_TUI.Geometry.Contains (Hit.Region, Point)
               then
                  Overlay := True;
                  Depth := Positive (Hit.Depth);
                  if not Layout.Items.Is_Empty then
                     for Item_Position in reverse
                       0 .. Natural (Layout.Items.Length) - 1
                     loop
                        declare
                           Item_Hit_Value : constant Item_Hit :=
                             Layout.Items.Element (Item_Position);
                        begin
                           if Item_Hit_Value.Depth = Depth
                             and then Flyology_TUI.Geometry.Contains
                               (Item_Hit_Value.Region, Point)
                           then
                              Item_Index := Item_Hit_Value.Index;
                              return;
                           end if;
                        end;
                     end loop;
                  end if;
                  return;
               end if;
            end;
         end loop;
      end if;
      if not Layout.Menus.Is_Empty then
         for Position in reverse 0 .. Natural (Layout.Menus.Length) - 1 loop
            declare
               Hit : constant Menu_Hit := Layout.Menus.Element (Position);
            begin
               if Hit.Depth = 0
                 and then Flyology_TUI.Geometry.Contains (Hit.Region, Point)
               then
                  Menu_Index := Hit.Index;
                  return;
               end if;
            end;
         end loop;
      end if;
   end Hit_Topmost;

   function Handle
     (Item   : in out Model;
      Event  : Flyology_TUI.Mouse.Local_Event;
      Layout : Presentation) return Update_Result
   is
      Point : constant Flyology_TUI.Geometry.Point :=
        (X => Event.X, Y => Event.Y);
      Menu_Index : Natural;
      Item_Index : Natural;
      Depth : Positive;
      Overlay : Boolean;
   begin
      if Event.Action = Flyology_TUI.Events.Mouse_Release
        and then Event.Button = Flyology_TUI.Events.Left_Button
        and then Item.Capturing
      then
         declare
            Armed : constant Natural := Item.Armed_Item;
            Can_Activate : constant Boolean := Armed > 0
              and then Item.Presentation_Revision =
                Item.Capture_State_Revision
              and then
                (Layout.Revision = Item.Capture_Layout_Revision
                 or else Layout.Revision = Item.Capture_State_Revision);
         begin
            Invalidate_Presentation (Item);
            Item.Capturing := False;
            Item.Armed_Item := 0;
            Item.Armed_Menu := 0;
            if Can_Activate then
               Hit_Topmost
                 (Layout, Point, Menu_Index, Item_Index, Depth, Overlay);
               if Item_Index = Armed then
                  declare
                     Result : Update_Result :=
                       Activate_Index (Item, Item_Index, Depth);
                  begin
                     Result.Event.Capture :=
                       Flyology_TUI.Components.Interactions.Release_Capture;
                     Result.Event.Focus_Requested := True;
                     return Result;
                  end;
               end if;
            end if;
            return Plain
              ((Handled => True,
                Capture =>
                  Flyology_TUI.Components.Interactions.Release_Capture,
                others => <>));
         end;
      elsif Layout.Revision /= Item.Presentation_Revision then
         return Plain
           ((Rejected => True, others => <>));
      elsif not Item.Enabled then
         return Plain (Flyology_TUI.Components.Interactions.Ignored);
      elsif Event.Action = Flyology_TUI.Events.Mouse_Release then
         return Plain (Flyology_TUI.Components.Interactions.Ignored);
      end if;

      Hit_Topmost
        (Layout, Point, Menu_Index, Item_Index, Depth, Overlay);
      if Event.Action = Flyology_TUI.Events.Mouse_Move then
         if Menu_Index > 0
           and then Item.Menus.Element (Menu_Index - 1).Enabled
           and then Is_Open (Item)
           and then Item.Open_Menus.First_Element /= Menu_Index
         then
            declare
               Changed : Boolean;
            begin
               Open_Top (Item, Menu_Index, Changed);
               return Plain
                 ((Handled => True, Changed => Changed, others => <>));
            end;
         elsif Item_Index > 0 and then Is_Selectable (Item, Item_Index) then
            declare
               Before : constant Natural :=
                 Item.Highlights.Element (Depth - 1);
               Definition : constant Stored_Item :=
                 Item.Items.Element (Item_Index - 1);
               Changed : Boolean := Before /= Item_Index;
               Path_Changed : Boolean;
            begin
               if Changed then
                  Invalidate_Presentation (Item);
                  Item.Highlights.Replace_Element (Depth - 1, Item_Index);
               end if;
               if Definition.Kind = Submenu_Item then
                  Open_Child (Item, Item_Index, Depth, Path_Changed);
                  Changed := Changed or else Path_Changed;
               else
                  Path_Changed :=
                    Natural (Item.Open_Menus.Length) > Depth;
                  if Path_Changed then
                     Invalidate_Presentation (Item);
                     while Natural (Item.Open_Menus.Length) > Depth loop
                        Item.Open_Menus.Delete_Last;
                        Item.Highlights.Delete_Last;
                     end loop;
                     Changed := True;
                  end if;
               end if;
               return Plain
                 ((Handled => True,
                   Changed => Changed,
                   others => <>));
            end;
         end if;
         return Plain (Flyology_TUI.Components.Interactions.Ignored);
      elsif Event.Action = Flyology_TUI.Events.Mouse_Drag
        and then Item.Capturing
      then
         return Plain ((Handled => True, others => <>));
      elsif Event.Action /= Flyology_TUI.Events.Mouse_Click
        or else Event.Button /= Flyology_TUI.Events.Left_Button
      then
         return Plain (Flyology_TUI.Components.Interactions.Ignored);
      end if;

      if Menu_Index > 0
        and then Item.Menus.Element (Menu_Index - 1).Enabled
      then
         declare
            Changed : Boolean;
            Press_Revision : constant Revision_Number := Layout.Revision;
         begin
            Open_Top (Item, Menu_Index, Changed);
            Invalidate_Presentation (Item);
            Item.Armed_Menu := Menu_Index;
            Item.Armed_Item := 0;
            Item.Capturing := True;
            Item.Capture_Layout_Revision := Press_Revision;
            Item.Capture_State_Revision := Item.Presentation_Revision;
            return Plain
              ((Handled => True, Focus_Requested => True,
                Changed => Changed,
                Capture =>
                  Flyology_TUI.Components.Interactions.Acquire_Capture,
                others => <>));
         end;
      elsif Item_Index > 0 then
         if not Is_Selectable (Item, Item_Index) then
            return Plain ((Handled => True, others => <>));
         end if;
         declare
            Changed : constant Boolean :=
              Item.Highlights.Element (Depth - 1) /= Item_Index;
            Press_Revision : constant Revision_Number := Layout.Revision;
         begin
            Invalidate_Presentation (Item);
            if Changed then
               Item.Highlights.Replace_Element (Depth - 1, Item_Index);
            end if;
            Item.Armed_Item := Item_Index;
            Item.Armed_Menu := 0;
            Item.Capturing := True;
            Item.Capture_Layout_Revision := Press_Revision;
            Item.Capture_State_Revision := Item.Presentation_Revision;
            return Plain
              ((Handled => True, Focus_Requested => True,
                Changed => Changed,
                Capture =>
                  Flyology_TUI.Components.Interactions.Acquire_Capture,
                others => <>));
         end;
      end if;
      if Overlay or else Is_Open (Item) then
         return Dismiss (Item);
      end if;
      return Plain (Flyology_TUI.Components.Interactions.Ignored);
   end Handle;

end Flyology_TUI.Components.Menubars;
