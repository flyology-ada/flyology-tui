package body Flyology_TUI.Components.Histories is

   --  Map a logical position, where 1 is the oldest retained entry, onto its
   --  slot in the ring.
   function Physical
     (Item : Model; Position : Positive) return Positive
   is ((((Item.First - 1) + (Position - 1)) mod Item.Max_Entries) + 1);

   function Value_At
     (Item : Model; Position : Positive) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Items (Physical (Item, Position))));

   function Starts_With
     (Value, Prefix : Wide_Wide_String) return Boolean
   is (Prefix'Length <= Value'Length
       and then Value (Value'First .. Value'First + Prefix'Length - 1)
                = Prefix);

   --  Index of the first occurrence of Needle in Value, or zero when absent.
   --  An empty needle matches at the start, so an empty query keeps every
   --  entry eligible while an incremental search is still being typed.
   function Index_Of (Value, Needle : Wide_Wide_String) return Natural is
   begin
      if Needle'Length = 0 then
         return Value'First;
      elsif Needle'Length > Value'Length then
         return 0;
      end if;
      for Start in Value'First .. Value'Last - Needle'Length + 1 loop
         if Value (Start .. Start + Needle'Length - 1) = Needle then
            return Start;
         end if;
      end loop;
      return 0;
   end Index_Of;

   function Contains (Value, Needle : Wide_Wide_String) return Boolean
   is (Index_Of (Value, Needle) /= 0);

   function Create
     (Max_Entries     : Positive;
      Max_Code_Points : Positive;
      Duplicates      : Duplicate_Policy) return Model is
   begin
      return Result : Model (Max_Entries, Max_Code_Points) do
         Result.Policy := Duplicates;
      end return;
   end Create;

   procedure Drop_Oldest (Item : in out Model) is
   begin
      Item.Total := Item.Total - Text.Length (Item.Items (Item.First));
      Item.Items (Item.First) := Text.Null_Unbounded_Wide_Wide_String;
      Item.First := (Item.First mod Item.Max_Entries) + 1;
      Item.Count := Item.Count - 1;
   end Drop_Oldest;

   --  Remove one logical position, moving every newer entry one step toward
   --  the oldest so the ring stays contiguous.
   procedure Remove_At (Item : in out Model; Position : Positive) is
   begin
      Item.Total :=
        Item.Total - Text.Length (Item.Items (Physical (Item, Position)));
      for Index in Position .. Item.Count - 1 loop
         Item.Items (Physical (Item, Index)) :=
           Item.Items (Physical (Item, Index + 1));
      end loop;
      Item.Items (Physical (Item, Item.Count)) :=
        Text.Null_Unbounded_Wide_Wide_String;
      Item.Count := Item.Count - 1;
   end Remove_At;

   procedure Append (Item : in out Model; Value : Wide_Wide_String) is
      Slot : constant Positive :=
        (((Item.First - 1) + Item.Count) mod Item.Max_Entries) + 1;
   begin
      Item.Items (Slot) := Text.To_Unbounded_Wide_Wide_String (Value);
      Item.Count := Item.Count + 1;
      Item.Total := Item.Total + Value'Length;
   end Append;

   function Add
     (Item  : in out Model;
      Value : Wide_Wide_String) return Add_Result
   is
      Evicted : Boolean := False;
   begin
      if Value'Length = 0 then
         return Ignored_Empty;
      elsif Value'Length > Item.Max_Code_Points then
         return Rejected_Capacity;
      end if;

      case Item.Policy is
         when Keep_Duplicates =>
            null;
         when Ignore_Consecutive =>
            if Item.Count > 0
              and then Value_At (Item, Item.Count) = Value
            then
               return Ignored_Duplicate;
            end if;
         when Ignore_Earlier =>
            for Position in reverse 1 .. Item.Count loop
               if Value_At (Item, Position) = Value then
                  Remove_At (Item, Position);
               end if;
            end loop;
      end case;

      while Item.Count = Item.Max_Entries
        or else Item.Total + Value'Length > Item.Max_Code_Points
      loop
         Drop_Oldest (Item);
         Evicted := True;
      end loop;

      Append (Item, Value);

      --  A retained submission ends any walk: the positions it was built on
      --  may no longer exist.
      Item.Mode := Idle;
      Item.Position := 0;
      Item.Prefix := Text.Null_Unbounded_Wide_Wide_String;
      Item.Needle := Text.Null_Unbounded_Wide_Wide_String;

      return (if Evicted then Added_After_Eviction else Added);
   end Add;

   procedure Clear (Item : in out Model) is
   begin
      for Index in Item.Items'Range loop
         Item.Items (Index) := Text.Null_Unbounded_Wide_Wide_String;
      end loop;
      Item.First := 1;
      Item.Count := 0;
      Item.Total := 0;
      Item.Mode := Idle;
      Item.Position := 0;
      Item.Prefix := Text.Null_Unbounded_Wide_Wide_String;
      Item.Needle := Text.Null_Unbounded_Wide_Wide_String;
   end Clear;

   procedure Set_Duplicates
     (Item : in out Model; Value : Duplicate_Policy) is
   begin
      Item.Policy := Value;
   end Set_Duplicates;

   function Length (Item : Model) return Natural is (Item.Count);

   function Is_Empty (Item : Model) return Boolean is (Item.Count = 0);

   function Code_Point_Count (Item : Model) return Natural is (Item.Total);

   function Duplicates (Item : Model) return Duplicate_Policy
   is (Item.Policy);

   function Entry_At
     (Item : Model; Position : Positive) return Wide_Wide_String
   is (Value_At (Item, Position));

   ---------------------------------------------------------------------
   --  Pluggable stores
   ---------------------------------------------------------------------

   package body Stores is

      procedure Save (Item : Model; Target : in out Store) is
      begin
         for Position in 1 .. Item.Count loop
            Write_Entry (Target, Value_At (Item, Position));
         end loop;
      end Save;

      procedure Load
        (Item     : in out Model;
         Source   : in out Store;
         Accepted : out Natural;
         Refused  : out Natural)
      is
         Value : Text.Unbounded_Wide_Wide_String;
         Available : Boolean;
      begin
         Accepted := 0;
         Refused := 0;
         loop
            Read_Entry (Source, Value, Available);
            exit when not Available;
            case Add (Item, Text.To_Wide_Wide_String (Value)) is
               when Added | Added_After_Eviction =>
                  Accepted := Accepted + 1;
               when Ignored_Empty | Ignored_Duplicate
                  | Rejected_Capacity =>
                  Refused := Refused + 1;
            end case;
         end loop;
      end Load;

   end Stores;

   ---------------------------------------------------------------------
   --  Browsing
   ---------------------------------------------------------------------

   procedure Begin_Browse
     (Item   : in out Model;
      Prefix : Wide_Wide_String := "") is
   begin
      Item.Mode := Browse;
      Item.Position := 0;
      Item.Prefix := Text.To_Unbounded_Wide_Wide_String (Prefix);
      Item.Needle := Text.Null_Unbounded_Wide_Wide_String;
   end Begin_Browse;

   function Browsing (Item : Model) return Boolean is (Item.Mode = Browse);

   function At_Live_Entry (Item : Model) return Boolean
   is (Item.Position = 0);

   procedure Browse_Older (Item : in out Model; Found : out Boolean) is
      Prefix : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Prefix);
      Start : Natural;
   begin
      Found := False;
      if Item.Mode /= Browse then
         return;
      end if;
      Start := (if Item.Position = 0 then Item.Count else Item.Position - 1);
      for Position in reverse 1 .. Start loop
         if Starts_With (Value_At (Item, Position), Prefix) then
            Item.Position := Position;
            Found := True;
            return;
         end if;
      end loop;
   end Browse_Older;

   procedure Browse_Newer (Item : in out Model; Found : out Boolean) is
      Prefix : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Prefix);
   begin
      Found := False;
      if Item.Mode /= Browse or else Item.Position = 0 then
         return;
      end if;
      for Position in Item.Position + 1 .. Item.Count loop
         if Starts_With (Value_At (Item, Position), Prefix) then
            Item.Position := Position;
            Found := True;
            return;
         end if;
      end loop;
      Item.Position := 0;
      Found := True;
   end Browse_Newer;

   function Browse_Value (Item : Model) return Wide_Wide_String
   is (Value_At (Item, Item.Position));

   procedure End_Browse (Item : in out Model) is
   begin
      if Item.Mode = Browse then
         Item.Mode := Idle;
         Item.Position := 0;
         Item.Prefix := Text.Null_Unbounded_Wide_Wide_String;
      end if;
   end End_Browse;

   ---------------------------------------------------------------------
   --  Incremental reverse search
   ---------------------------------------------------------------------

   procedure Begin_Search (Item : in out Model) is
   begin
      Item.Mode := Search;
      Item.Position := 0;
      Item.Prefix := Text.Null_Unbounded_Wide_Wide_String;
      Item.Needle := Text.Null_Unbounded_Wide_Wide_String;
   end Begin_Search;

   function Searching (Item : Model) return Boolean is (Item.Mode = Search);

   procedure Set_Query (Item : in out Model; Query : Wide_Wide_String) is
      Start : Natural;
   begin
      if Item.Mode /= Search then
         return;
      end if;
      Item.Needle := Text.To_Unbounded_Wide_Wide_String (Query);
      if Item.Position > 0
        and then Contains (Value_At (Item, Item.Position), Query)
      then
         return;
      end if;
      Start := (if Item.Position = 0 then Item.Count else Item.Position);
      for Position in reverse 1 .. Start loop
         if Contains (Value_At (Item, Position), Query) then
            Item.Position := Position;
            return;
         end if;
      end loop;
      Item.Position := 0;
   end Set_Query;

   function Query (Item : Model) return Wide_Wide_String
   is (Text.To_Wide_Wide_String (Item.Needle));

   procedure Search_Older (Item : in out Model; Found : out Boolean) is
      Needle : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Needle);
      Start : Natural;
   begin
      Found := False;
      if Item.Mode /= Search then
         return;
      end if;
      Start := (if Item.Position = 0 then Item.Count else Item.Position - 1);
      for Position in reverse 1 .. Start loop
         if Contains (Value_At (Item, Position), Needle) then
            Item.Position := Position;
            Found := True;
            return;
         end if;
      end loop;
   end Search_Older;

   procedure Search_Newer (Item : in out Model; Found : out Boolean) is
      Needle : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Needle);
   begin
      Found := False;
      if Item.Mode /= Search or else Item.Position = 0 then
         return;
      end if;
      for Position in Item.Position + 1 .. Item.Count loop
         if Contains (Value_At (Item, Position), Needle) then
            Item.Position := Position;
            Found := True;
            return;
         end if;
      end loop;
   end Search_Newer;

   function Has_Match (Item : Model) return Boolean
   is (Item.Mode = Search and then Item.Position > 0);

   function Match_Value (Item : Model) return Wide_Wide_String
   is (Value_At (Item, Item.Position));

   procedure Match_Range
     (Item : Model; First, Last : out Natural)
   is
      Value : constant Wide_Wide_String := Match_Value (Item);
      Needle : constant Wide_Wide_String :=
        Text.To_Wide_Wide_String (Item.Needle);
      Start : constant Natural := Index_Of (Value, Needle);
   begin
      if Needle'Length = 0 or else Start = 0 then
         First := 0;
         Last := 0;
      else
         First := Start - Value'First;
         Last := First + Needle'Length;
      end if;
   end Match_Range;

   procedure End_Search (Item : in out Model) is
   begin
      if Item.Mode = Search then
         Item.Mode := Idle;
         Item.Position := 0;
         Item.Needle := Text.Null_Unbounded_Wide_Wide_String;
      end if;
   end End_Search;

   ---------------------------------------------------------------------
   --  Hinting
   ---------------------------------------------------------------------

   function Suggestion
     (Item : Model; Prefix : Wide_Wide_String) return Wide_Wide_String is
   begin
      if Prefix'Length = 0 then
         return "";
      end if;
      for Position in reverse 1 .. Item.Count loop
         declare
            Candidate : constant Wide_Wide_String := Value_At (Item, Position);
         begin
            if Candidate'Length > Prefix'Length
              and then Starts_With (Candidate, Prefix)
            then
               return Candidate;
            end if;
         end;
      end loop;
      return "";
   end Suggestion;

end Flyology_TUI.Components.Histories;
