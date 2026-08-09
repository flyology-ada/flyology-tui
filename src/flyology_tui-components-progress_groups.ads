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
   type Progress_Mode is (Determinate, Indeterminate);
   type Work_State is
     (Pending, Running, Paused, Succeeded, Failed, Cancelled);

   type Appearance is record
      Label         : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Selected      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Complete      : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Remaining     : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Indeterminate : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Pending_State : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Running_State : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Paused_State  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Success_State : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Failed_State  : Flyology_TUI.Styles.Style := Flyology_TUI.Styles.Default;
      Cancelled_State : Flyology_TUI.Styles.Style :=
        Flyology_TUI.Styles.Default;
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
      Value         : Fraction := 0.0;
      Work          : Work_State := Running);

   procedure Add_Indeterminate
     (Item          : in out Model;
      Id            : Item_Id;
      Label         : Wide_Wide_String;
      Relative_Weight : Weight := 1.0;
      Work          : Work_State := Running);

   procedure Remove (Item : in out Model; Id : Item_Id);
   function Contains (Item : Model; Id : Item_Id) return Boolean;

   procedure Set_Value
     (Item : in out Model;
      Id   : Item_Id;
      Value : Fraction);

   procedure Set_Mode
     (Item : in out Model;
      Id   : Item_Id;
      Mode : Progress_Mode);

   procedure Set_Work_State
     (Item : in out Model;
      Id   : Item_Id;
      Work : Work_State);

   --  Advance only Running, Indeterminate rows. Applications call this from
   --  their own Tick/update policy; the component owns no clock or task.
   procedure Advance (Item : in out Model; Steps : Positive := 1);

   function Length (Item : Model) return Natural;
   function Is_Empty (Item : Model) return Boolean;
   function Mode (Item : Model; Id : Item_Id) return Progress_Mode;
   function Work_Status (Item : Model; Id : Item_Id) return Work_State;
   function Value (Item : Model; Id : Item_Id) return Fraction
     with Pre => Mode (Item, Id) = Determinate;

   function Has_Selection (Item : Model) return Boolean;
   function Selected_Id (Item : Model) return Item_Id
     with Pre => Has_Selection (Item);
   procedure Select_Item (Item : in out Model; Id : Item_Id);

   --  Weighted mean of positive-weight contributions. Cancelled rows and
   --  Running, Paused, or Failed Indeterminate rows are excluded. Succeeded
   --  rows contribute 1.0 regardless of mode; Pending Indeterminate rows
   --  contribute 0.0; every other Determinate row contributes Value. An empty
   --  total is 0.0.
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
   --  fraction; Indeterminate segments render Phase, which advances only for
   --  Running rows. Succeeded overrides measurement mode and renders its
   --  segment completely filled.
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
      Measurement : Progress_Mode := Determinate;
      Work     : Work_State := Running;
      Current  : Fraction := 0.0;
      Relative_Weight : Weight := 1.0;
      Phase    : Natural := 0;
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
