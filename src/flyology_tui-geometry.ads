package Flyology_TUI.Geometry is
   type Point is record
      X : Integer := 0;
      Y : Integer := 0;
   end record;

   type Rectangle is record
      X      : Integer := 0;
      Y      : Integer := 0;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;

   --  Test a signed point without overflowing at either Integer boundary.
   function Contains (Item : Rectangle; Value : Point) return Boolean;

   function Contains
     (Item : Rectangle;
      X, Y : Integer) return Boolean;
end Flyology_TUI.Geometry;
