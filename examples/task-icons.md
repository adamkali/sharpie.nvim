# Task/Async Icon Detection

sharpie.nvim automatically detects Task return types and displays them with an hourglass icon (⏳).

## Detected Patterns

The following patterns are detected as Task-returning methods:

### Direct Task Returns (No Generic)
```csharp
public Task DoSomethingAsync()          // ⏳ (hourglass - no return type)
public ValueTask DoFastAsync()          // ⏳ (hourglass - no return type)
```

### Task<T> Returns (Shows T's Icon)
```csharp
public Task<int> GetCountAsync()        //  (integer icon)
public Task<string> GetNameAsync()      // 󰀬 (string icon)
public Task<bool> IsReadyAsync()        //  (boolean icon)
public Task<User> GetUserAsync()        //  (class icon)
public Task<List<Item>> GetItemsAsync() // 󰅪 (array icon)
public ValueTask<double> CalculateAsync() //  (number icon)
```

### Async Keyword
```csharp
public async Task ProcessAsync()        // ⏳
private async Task<string> FetchAsync() // ⏳
internal async ValueTask SaveAsync()    // ⏳
```

### Async Enumerables
```csharp
public IAsyncEnumerable<Item> StreamItemsAsync()  // ⏳
```

## Display in Preview

```
Symbol Preview
─────────────────────────────────
  MyNamespace
   MyNamespace.UserService
 () MyNamespace.UserService.Users               # Property
 () MyNamespace.UserService.GetUsers()          # Sync method returning User[]
⏳ () MyNamespace.UserService.DoWorkAsync()      # Task (no return value)
 () MyNamespace.UserService.GetUserAsync(int id) # Task<User> (returns User)
  () MyNamespace.UserService.GetCountAsync()    # Task<int> (returns int)
󰀬 () MyNamespace.UserService.GetNameAsync()     # Task<string> (returns string)
󰅪 () MyNamespace.UserService.GetAllAsync()      # Task<List<User>> (returns list)
```

## Configuration

The Task icon can be customized:

```lua
require('sharpie').setup({
    style = {
        icon_set = {
            task = "⏳",  -- Default hourglass
            -- Or use alternatives:
            -- task = "",  -- Lightning bolt
            -- task = "󰔟",  -- Async symbol
            -- task = "",  -- Clock
            -- task = "",  -- Rocket (fast async)
        }
    }
})
```

## Icon Priority

The icon selection follows this priority:

1. **Task<T> Generic Return Type** → Icon for type `T`
   - `Task<int>` →
   - `Task<string>` → 󰀬
   - `Task<bool>` →
   - `Task<User>` →  (class)
   - `Task<List<T>>` → 󰅪 (array)

2. **Task Return Type (No Generic)** → Hourglass icon (⏳)
   - `Task` → ⏳
   - `ValueTask` → ⏳

3. **Class/Object Types** → Class icon ()
   - For symbols with kind "object" or "unknown" but detail indicates class/interface/struct

4. **Default Kind-Based Icon** → Standard LSP kind icon
   - Method:
   - Property:
   - Field:
   - etc.

## Type Detection

The plugin intelligently maps C# types to icons:

### Primitive Types
- `int`, `Int32`, `long`, `short`, `byte` →
- `string` → 󰀬
- `bool`, `boolean` →
- `float`, `double`, `decimal` →
- `void` → 󰟢

### Collection Types
- `List<T>`, `IEnumerable<T>`, `T[]` → 󰅪
- `Dictionary<K,V>`, `IDictionary<K,V>` →

### Object Types
- Custom classes (e.g., `User`, `Product`) →
- Interfaces, structs →

## Examples

### Service Class
```csharp
public class DataService
{
    // Regular method returning User
    public User GetUser(int id) { }                //  GetUser()

    // Async method returning Task (no generic)
    public async Task SaveUserAsync(User user) { } // ⏳ SaveUserAsync()

    // Async method returning Task<User>
    public Task<User> GetUserAsync(int id) { }     //  GetUserAsync()

    // Async method returning Task<int>
    public Task<int> GetCountAsync() { }           //  GetCountAsync()

    // Async method returning Task<string>
    public Task<string> GetNameAsync() { }         // 󰀬 GetNameAsync()

    // Async method returning Task<List<User>>
    public Task<List<User>> GetAllAsync() { }      // 󰅪 GetAllAsync()

    // Property
    public bool IsReady { get; }                   //  IsReady
}
```

### Preview Display
```
  DataService
 () DataService.GetUser(int id)          # Regular method
⏳ () DataService.SaveUserAsync(User u)   # Task (void)
 () DataService.GetUserAsync(int id)     # Task<User>
  () DataService.GetCountAsync()         # Task<int>
󰀬 () DataService.GetNameAsync()          # Task<string>
󰅪 () DataService.GetAllAsync()           # Task<List<User>>
 () DataService.IsReady                  # Property
```

## Benefits

1. **Quick Visual Identification**: Spot async methods at a glance
2. **Consistent**: Works in both preview window and fuzzy finder
3. **Automatic**: No manual tagging needed
4. **Smart Detection**: Handles various Task patterns
5. **Customizable**: Change the icon to your preference

## Logging

Task detection is logged when debug logging is enabled:

```vim
:SharpieLogLevel DEBUG
:SharpieShow
:SharpieLog
```

Look for entries like:
```
[DEBUG] symbol_utils: Detected Task return type: Task<User>
[DEBUG] symbol_utils: Using task icon for symbol: GetUserAsync
```
