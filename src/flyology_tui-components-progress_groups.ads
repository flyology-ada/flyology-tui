with Ada.Strings.Wide_Wide_Unbounded;
with Flyology_TUI.Components.Interactions;
with Flyology_TUI.Events;
with Flyology_TUI.Mouse;
with Flyology_TUI.Styles;
with Flyology_TUI.Surfaces;
with Flyology_TUI.Themes;

generic
   type Item_Id is private;
   Maximum_Items : Positive;
package Flyology_TUI.Components.Progress_Groups is
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   subtype Fraction is Long_Float range 0.0 .. 1.0;
   subtype Weight is Long_Float range 0.0 .. Long_Float'Last;
   type Progress_State is (Determinate, Indeterminate);

   type Appearance is record
      Label         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Complete      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Remaining     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Indeterminate : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
   end record;

   function From_Theme
     (Theme : Flyology_TUI.Themes.Theme) return Appearance;

   type Model is tagged private;

   function Create (Width : Natural := 40) return Model;

   procedure Add_Determinate
     (Item          : in out Model;
      Id            : Item_Id;
      Label         : Wide_Wide_String;
      Relative_Weight : Weight := 1.0;
      Value         : Fraction := 0.0);

   procedure Add_Indeterminate
     (Item          : in out Model;
      Id            : Item_Id;
      Label         : Wide_Wide_String;
      Relative_Weight : Weight := 1.0);

   procedure Remove (Item : in out Model; Id : Item_Id);
   function Contains (Item : Model; Id : Item_Id) return Boolean;

   procedure Set_Value
     (Item : in out Model;
      Id   : Item_Id;
      Value : Fraction);

   procedure Set_Indeterminate (Item : in out Model; Id : Item_Id);

   --  Advance only indeterminate rows. Applications call this from their own
   --  Tick/update policy; the component owns no clock or task.
   procedure Advance (Item : in out Model; Steps : Positive := 1);

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function State (Item : Model; Id : Item_Id) return Progress_State;
   function Value (Item : Model; Id : Item_Id) return Fraction
     with Pre => State (Item, Id) = Determinate;

   function Has_Selection (Item : Model) return Boolean;
   function Selected_Id (Item : Model) return Item_Id
     with Pre => Has_Selection (Item);
   procedure Select_Item (Item : in out Model; Id : Item_Id);

   --  Weighted mean of determinate rows with positive weight. Indeterminate
   --  and zero-weight rows do not participate; an empty total is 0.0.
   function Weighted_Total (Item : Model) return Fraction;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   function Handle
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event)
      return Flyology_TUI.Components.Interactions.Update_Result;

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Events.Terminal_Event);

   procedure Update
     (Item  : in out Model;
      Event : Flyology_TUI.Mouse.Local_Event);

   function Render
     (Item       : Model;
      Appearance : Progress_Groups.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Render
     (Item  : Model;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

   --  Render all positive-weight rows as adjacent segments in one line.
   --  Segment widths follow Relative_Weight in insertion order. Remaining
   --  cells after flooring go to the largest fractional remainders, with
   --  insertion order breaking ties. Determinate segments use their own
   --  fraction and indeterminate segments use Phase.
   function Render_Segments
     (Item       : Model;
      Width      : Natural;
      Appearance : Progress_Groups.Appearance := (others => <>))
      return Flyology_TUI.Surfaces.Surface;

   function Render_Segments
     (Item  : Model;
      Width : Natural;
      Theme : Flyology_TUI.Themes.Theme)
      return Flyology_TUI.Surfaces.Surface;

private
   type Row_Entry is record
      Id       : Item_Id;
      Label    : Text.Unbounded_Wide_Wide_String;
      Kind     : Progress_State := Determinate;
      Current  : Fraction := 0.0;
      Relative_Weight : Weight := 1.0;
      Phase    : Natural range 0 .. 3 := 0;
   end record;

   type Entry_Array is
     array (Positive range 1 .. Maximum_Items) of Row_Entry;

   type Model is tagged record
      Entries  : Entry_Array;
      Count    : Natural range 0 .. Maximum_Items := 0;
      Selected : Natural range 0 .. Maximum_Items := 0;
      Columns  : Natural := 40;
   end record;
end Flyology_TUI.Components.Progress_Groups;
