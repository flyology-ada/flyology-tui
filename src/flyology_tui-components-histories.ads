with Ada.Strings.Wide_Wide_Unbounded;

--  A bounded command history: the retained past entries of a prompt, the
--  newest-first walk an Up arrow performs, and the incremental reverse
--  search a Ctrl-R performs. The model owns text only; it renders nothing,
--  starts no task, and performs no I/O, so an application can keep it in
--  any store it already has through the nested Stores generic.
package Flyology_TUI.Components.Histories is

   --  Local name for the unbounded wide-string type entries are built from.
   package Text renames Ada.Strings.Wide_Wide_Unbounded;

   --  How Add treats an entry equal to one already retained.
   --  @enum Keep_Duplicates Retain every accepted entry
   --  @enum Ignore_Consecutive Ignore an entry equal to the newest one
   --  @enum Ignore_Earlier Remove equal earlier entries, then retain
   type Duplicate_Policy is
     (Keep_Duplicates,
      Ignore_Consecutive,
      Ignore_Earlier);

   --  Outcome of one Add. Every outcome leaves the model consistent, and a
   --  rejected Add leaves it completely unchanged.
   --
   --  Ignored_Empty refuses only the empty string: which blank input a
   --  shell discards is application policy, so a caller that suppresses
   --  whitespace-only entries trims before adding.
   --  @enum Added Retained without evicting anything
   --  @enum Added_After_Eviction Retained after evicting oldest entries
   --  @enum Ignored_Empty Refused because the value is empty
   --  @enum Ignored_Duplicate Refused under the active Duplicate_Policy
   --  @enum Rejected_Capacity Refused: the value exceeds Max_Code_Points
   type Add_Result is
     (Added,
      Added_After_Eviction,
      Ignored_Empty,
      Ignored_Duplicate,
      Rejected_Capacity);

   --  A model owns its bounded entry storage. It is limited so construction
   --  is build-in-place and ownership cannot be copied.
   --  @field Max_Entries Greatest number of entries retained at once
   --  @field Max_Code_Points Greatest total code points retained at once
   type Model
     (Max_Entries     : Positive;
      Max_Code_Points : Positive) is tagged limited private;

   --  Duplicates has no default: how a shell treats repeated commands is
   --  application policy, not a property this component can derive.
   --  @param Max_Entries Greatest number of entries retained at once
   --  @param Max_Code_Points Greatest total code points retained at once
   --  @param Duplicates How an entry equal to a retained one is treated
   --  @return A history retaining nothing
   function Create
     (Max_Entries     : Positive;
      Max_Code_Points : Positive;
      Duplicates      : Duplicate_Policy) return Model;

   --  Retain Value as the newest entry. Oldest entries are evicted until
   --  both the entry count and the total code-point budget hold.
   --  @param Item History to add to
   --  @param Value Text to retain
   --  @return Whether the value was retained, ignored, or refused
   function Add
     (Item  : in out Model;
      Value : Wide_Wide_String) return Add_Result;

   --  Discard every retained entry and end any walk or search.
   --  @param Item History to empty
   procedure Clear (Item : in out Model);

   --  Replace the duplicate policy without disturbing retained entries. A
   --  component that owns a history as a record part sets the policy here,
   --  because a part is default-initialized rather than built by Create.
   --  @param Item History to reconfigure
   --  @param Value Policy to apply to later additions
   procedure Set_Duplicates
     (Item : in out Model; Value : Duplicate_Policy);

   --  Count the retained entries.
   --  @param Item History to measure
   --  @return Number of retained entries
   function Length (Item : Model) return Natural;

   --  Report whether any entry is retained.
   --  @param Item History to measure
   --  @return True when nothing is retained
   function Is_Empty (Item : Model) return Boolean;

   --  Measure the retained text.
   --  @param Item History to measure
   --  @return Total code points across every retained entry
   function Code_Point_Count (Item : Model) return Natural;

   --  Report the policy applied to later additions.
   --  @param Item History to inspect
   --  @return The policy applied to later additions
   function Duplicates (Item : Model) return Duplicate_Policy;

   --  Position 1 is the oldest retained entry and Length is the newest.
   --  @param Item History to inspect
   --  @param Position Oldest-first position of the wanted entry
   --  @return Text retained at that position
   function Entry_At
     (Item : Model; Position : Positive) return Wide_Wide_String
     with Pre => Position <= Length (Item);

   --------------------------------------------------------------------
   --  Pluggable stores
   --------------------------------------------------------------------

   --  Move a history between this model and whatever the application
   --  already persists with: a file, a database, a byte buffer. The
   --  component still performs no I/O; the store does, and this generic
   --  contributes only the oldest-first ordering and the bounding.
   --  @formal Store Caller-owned handle to the backing store
   --  @formal Write_Entry Appends one entry to the store
   --  @formal Read_Entry Yields the next entry from the store
   generic
      type Store (<>) is limited private;
      --  Append one entry. Save calls this once per retained entry,
      --  oldest first.
      --  @param Target Store being written
      --  @param Value Entry text to append
      with procedure Write_Entry
        (Target : in out Store;
         Value  : Wide_Wide_String);
      --  Yield the next entry, oldest first. Load calls this until
      --  Available is False.
      --  @param Source Store being read
      --  @param Value Entry text that was read
      --  @param Available False once the store is exhausted
      with procedure Read_Entry
        (Source    : in out Store;
         Value     : out Text.Unbounded_Wide_Wide_String;
         Available : out Boolean);
   package Stores is

      --  Write every retained entry, oldest first, so a later Load
      --  reproduces the same order.
      --  @param Item History to persist
      --  @param Target Store to write into
      procedure Save (Item : Model; Target : in out Store);

      --  Read entries until the store is exhausted, adding each as the
      --  newest. Load appends rather than replacing, so a caller restoring
      --  a saved history into a used model calls Clear first. Entries the
      --  model refuses are counted rather than raising, because a store
      --  written by an older build may hold entries this model cannot take.
      --  @param Item History to restore into
      --  @param Source Store to read from
      --  @param Accepted Number of entries the model retained
      --  @param Refused Number of entries the model would not retain
      procedure Load
        (Item     : in out Model;
         Source   : in out Store;
         Accepted : out Natural;
         Refused  : out Natural);

   end Stores;

   --------------------------------------------------------------------
   --  Browsing
   --------------------------------------------------------------------

   --  Begin a newest-first walk. A non-empty Prefix restricts the walk to
   --  entries beginning with it, which is what a prefix-constrained Up
   --  arrow needs. Browsing starts at the live entry, meaning the caller's
   --  own buffer rather than any retained entry.
   --  @param Item History to walk
   --  @param Prefix Restricts the walk to entries beginning with it
   procedure Begin_Browse
     (Item   : in out Model;
      Prefix : Wide_Wide_String := "");

   --  Report whether a walk is in progress.
   --  @param Item History to inspect
   --  @return True while a walk is in progress
   function Browsing (Item : Model) return Boolean;

   --  True while the walk sits above the newest retained entry, where the
   --  caller's live buffer belongs.
   --  @param Item History to inspect
   --  @return True when the walk is at the caller's own input
   function At_Live_Entry (Item : Model) return Boolean;

   --  Step one matching entry toward the oldest. Found is False when no
   --  further entry matches, and the position is then left unchanged.
   --  @param Item History to walk
   --  @param Found Whether a further matching entry existed
   procedure Browse_Older (Item : in out Model; Found : out Boolean);

   --  Step one matching entry toward the newest, returning to the live
   --  entry past the newest match. Found is False only when already at the
   --  live entry.
   --  @param Item History to walk
   --  @param Found Whether the walk moved
   procedure Browse_Newer (Item : in out Model; Found : out Boolean);

   --  Read the entry the walk currently sits on.
   --  @param Item History being walked
   --  @return Text of the entry the walk currently sits on
   function Browse_Value (Item : Model) return Wide_Wide_String
     with Pre => Browsing (Item) and then not At_Live_Entry (Item);

   --  End the walk, leaving retained entries untouched.
   --  @param Item History being walked
   procedure End_Browse (Item : in out Model);

   --------------------------------------------------------------------
   --  Incremental reverse search
   --------------------------------------------------------------------

   --  Begin an incremental search with an empty query, anchored above the
   --  newest entry. Browsing and searching are mutually exclusive; starting
   --  one ends the other.
   --  @param Item History to search
   procedure Begin_Search (Item : in out Model);

   --  Report whether a search is in progress.
   --  @param Item History to inspect
   --  @return True while a search is in progress
   function Searching (Item : Model) return Boolean;

   --  Replace the query. The current match is kept when it still contains
   --  the new query; otherwise the search moves toward the oldest entry
   --  from the current position, which is how an incremental search
   --  narrows as the user types.
   --  @param Item History being searched
   --  @param Query Text the match must contain
   procedure Set_Query (Item : in out Model; Query : Wide_Wide_String);

   --  Read the query the search is narrowing on.
   --  @param Item History being searched
   --  @return The query the search is narrowing on
   function Query (Item : Model) return Wide_Wide_String;

   --  Step to the next entry containing the query, toward the oldest.
   --  @param Item History being searched
   --  @param Found Whether a further match existed
   procedure Search_Older (Item : in out Model; Found : out Boolean);

   --  Step to the next entry containing the query, toward the newest.
   --  @param Item History being searched
   --  @param Found Whether a further match existed
   procedure Search_Newer (Item : in out Model; Found : out Boolean);

   --  Report whether the query matches a retained entry.
   --  @param Item History being searched
   --  @return True when the query currently matches a retained entry
   function Has_Match (Item : Model) return Boolean;

   --  Read the entry the query matches.
   --  @param Item History being searched
   --  @return Text of the matching entry
   function Match_Value (Item : Model) return Wide_Wide_String
     with Pre => Has_Match (Item);

   --  Half-open code-point range [First, Last) of the query inside
   --  Match_Value, ready for a Highlights overlay. An empty query reports
   --  an empty range.
   --  @param Item History being searched
   --  @param First Code-point offset the query starts at
   --  @param Last Code-point offset immediately after the query
   procedure Match_Range
     (Item : Model; First, Last : out Natural)
     with Pre => Has_Match (Item);

   --  End the search, leaving retained entries untouched.
   --  @param Item History being searched
   procedure End_Search (Item : in out Model);

   --------------------------------------------------------------------
   --  Hinting
   --------------------------------------------------------------------

   --  Newest retained entry that begins with Prefix and is strictly longer
   --  than it. This is the source a prompt uses for inline ghost text. An
   --  empty Prefix, or no match, returns the empty string.
   --  @param Item History to search
   --  @param Prefix Text the suggestion must extend
   --  @return The newest extending entry, or the empty string
   function Suggestion
     (Item : Model; Prefix : Wide_Wide_String) return Wide_Wide_String;

private
   type Entry_Array is
     array (Positive range <>) of Text.Unbounded_Wide_Wide_String;

   type Walk_Mode is (Idle, Browse, Search);

   --  Items is ring storage whose oldest retained entry is Items (First).
   --  Position is a logical position, oldest-first, where zero means the
   --  live entry the caller still owns.
   type Model
     (Max_Entries     : Positive;
      Max_Code_Points : Positive) is
   tagged limited record
      Items    : Entry_Array (1 .. Max_Entries);
      First    : Positive := 1;
      Count    : Natural := 0;
      Total    : Natural := 0;
      Policy   : Duplicate_Policy := Keep_Duplicates;
      Mode     : Walk_Mode := Idle;
      Position : Natural := 0;
      Prefix   : Text.Unbounded_Wide_Wide_String;
      Needle   : Text.Unbounded_Wide_Wide_String;
   end record;
end Flyology_TUI.Components.Histories;
