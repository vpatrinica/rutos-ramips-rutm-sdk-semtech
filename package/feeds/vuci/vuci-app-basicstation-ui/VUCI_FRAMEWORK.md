# Teltonika VUCI Framework — Data Loading & Component Reference

> **Source**: Reverse-engineered from compiled `index-2026-01-21-135a9278bb8.js.gz` and `vendor-*.js.gz`
> in `vuci-ui-core/bin/vuci-ui-core/src/dist/www/assets/`.

## Overview

The Teltonika VUCI framework is a **fork** of the open-source [vuci](https://github.com/zhaojh329/vuci) project. It extends the standard components with Teltonika-specific props like `endpoints` and `data-key` that are **not documented** in the upstream vuci docs.

### Key Difference from Upstream vuci

| Feature | Upstream vuci | Teltonika VUCI |
|---------|---------------|----------------|
| Form prop | `uci-config="name"` | `config="name"` |
| Data loading | Form loads via ubus internally | Form collects `endpoints` from child sections, calls `$axios.bulkGet()` |
| Section data binding | Auto-bound by parent form | Via `data-key` → `uciData[dataKey]` |
| Section endpoints | Not needed | **Required** — `endpoints` array on each section |

---

## Data Loading Flow

```
┌──────────────────────────────────────────────┐
│  vuci-form (config="basicstation")           │
│                                              │
│  mounted() → loadData() → _loadData()        │
│      │                                       │
│      ├─ _getEndpoints()                      │
│      │   Iterates vuciSections               │
│      │   Calls each section's getData()      │
│      │   Collects: [endpoints[], dataKeys[]] │
│      │                                       │
│      ├─ $axios.bulkGet(allEndpoints)         │
│      │   Sends parallel GET requests         │
│      │                                       │
│      └─ Distributes responses:               │
│         uciData[dataKey] = responseData      │
│                                              │
│  Sections read: this.uciData[this.dataKey]   │
└──────────────────────────────────────────────┘
```

### Section Registration

Each section registers itself with the parent form on mount:

```javascript
// Section watch (immediate)
this.vuciForm.vuciSections[`${this.configName}_${this.sid}`] = {
  saveable: this.isSaveable,
  load: this.load,
  callMethod: this.callMethod,
  dataKey: this.dataKey,
  awaitNetwork: this.awaitNetwork,
  // ...more exposed properties
}
```

---

## vuci-form

Represents a UCI configuration. All section components must be wrapped by this component.

### Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `config` | `String` | Yes | UCI config name (e.g. `"basicstation"`) |
| `editing` | `Boolean` | No | Whether form is in editing mode |
| `afterLoad` | `Function` | No | Called after data is loaded |
| `extraLoad` | `Function` | No | Load additional data beyond endpoints |
| `asyncLoad` | `Boolean` | No | Load sections asynchronously |
| `beforeSave` | `Function` | No | Validation before save |
| `bulkRequest` | `Boolean` | No | Batch save requests |
| `successSaveMessage` | `String` | No | Custom success message |
| `custom-save` | - | No | **Suppresses** native save — use only with `@save` handler |

### Scoped Slot

```html
<vuci-form config="basicstation" v-slot="{ uciData }">
  <!-- uciData = { dataKey1: [...sections], dataKey2: [...sections] } -->
</vuci-form>
```

### Internal State

```javascript
data() {
  return {
    uciData: {},           // { [dataKey]: sectionData[] }
    vuciSections: {},      // { [configName_sid]: exposedProperties }
    initialForm: {},       // snapshot for dirty checking
    loaded: false
  }
}
```

### Key Computed Properties

```javascript
isSaveable() {
  // Iterates all registered sections
  return Object.values(this.vuciSections).some(e => e.saveable)
}
```

> **⚠️ Common Error**: `TypeError: Cannot read properties of undefined (reading 'saveable')`
> — caused when a section registers in `vuciSections` but then gets destroyed/unmounted
> before the form checks `isSaveable`. Ensure sections are always properly mounted.

---

## vuci-named-section

Represents a **single named UCI section** (e.g. `config station 'station'`).

### Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `name` | `String` | Yes | UCI section name (e.g. `"auth"`) |
| `title` | `String` | No | Card/section title |
| `endpoints` | `Array` | **Yes** | Array of `{ endpoint: '...' }` objects |
| `data-key` | `String` | **Yes** | Key in `uciData` to store/retrieve data |

### URL Construction (Critical!)

The framework **auto-appends** `/{sectionName}` to the endpoint:

```javascript
// Named section getData()
getData() {
  return [{
    endpoints: this.endpoints.map(e => `/api/${e.endpoint}/${this.sectionName}`),
    dataKey: this.dataKey
  }]
}
```

**Example:**

```html
<vuci-named-section name="auth"
  :endpoints="[{ endpoint: 'basicstation/config' }]"
  data-key="auth">
```

→ Framework calls: **`GET /api/basicstation/config/auth`**

### Data Retrieval

```javascript
// Section reads its data from parent form's uciData
data() {
  return this.uciData[this.dataKey]
    ? this.uciData[this.dataKey]
    : []
}
```

### Scoped Slot

```html
<vuci-named-section name="auth" v-slot="{ s }">
  <!-- s = the section data object { .name, .type, key1, key2, ... } -->
  <vuci-form-item-input :uci-section="s" name="addr" />
</vuci-named-section>
```

---

## vuci-typed-section

Represents **all UCI sections of the same type** (e.g. all `config rfconf` sections), displayed as a table.

### Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `type` | `String` | Yes | UCI section type (e.g. `"rfconf"`) |
| `title` | `String` | No | Card/section title |
| `columns` | `Array` | Yes | Column definitions: `[{ name, label }]` |
| `endpoints` | `Array` | **Yes** | Array of `{ endpoint: '...' }` objects |
| `data-key` | `String` | **Yes** | Key in `uciData` to store/retrieve data |
| `addremove` | `Boolean` | No | Allow adding/removing rows |
| `filter` | `Function` | No | Filter function `(section) => boolean` |
| `add` | `Function` | No | Custom add function |

### URL Construction

Typed sections use the endpoint **as-is** (no auto-append):

```javascript
// Typed section getData()
getData() {
  return [{
    endpoints: this.endpoints.map(s => `/api/${s.endpoint}`),
    dataKey: this.dataKey
  }]
}
```

**Example:**

```html
<vuci-typed-section type="rfconf"
  :endpoints="[{ endpoint: 'basicstation/rfconf' }]"
  data-key="rfconf">
```

→ Framework calls: **`GET /api/basicstation/rfconf`**

### Column Slot Templates

```html
<vuci-typed-section type="rfconf" :columns="rfConfColumns">
  <template #freq="{ s }">
    <vuci-form-item-input :uci-section="s" name="freq" />
  </template>
</vuci-typed-section>
```

---

## API Response Format

The VUCI framework expects responses in this format:

```json
{
  "data": [
    { ".name": "auth", ".type": "auth", "id": "auth", "addr": "eu1.cloud...", "port": "8887", ... },
  ]
}
```

The framework handles both arrays and single objects:

```javascript
// In _loadData:
const c = isArray(r.data) ? r.data : [r.data];
// Always normalised to an array
```

Each section object should have:

- `.name` — UCI section name (used as identifier)
- `.type` — UCI section type
- `id` — typically same as `.name`
- All other UCI option key-value pairs

### Lua Backend Pattern

```lua
function MyService:GET_TYPE_config(sid)
    local cursor = uci.cursor()
    local section = cursor:get_all("basicstation", sid)
    section[".name"] = sid
    section["id"] = sid
    return self:ResponseOK(section)  -- single object, framework wraps in array
end

function MyService:GET_TYPE_rfconf()
    local data = {}
    cursor:foreach("basicstation", "rfconf", function(s)
        s["id"] = s[".name"]
        table.insert(data, s)
    end)
    return self:ResponseOK(data)  -- array of sections
end
```

---

## Save Flow

### Standard Save (without `custom-save`)

```
Save button clicked
    → vuci-form.save()
    → foreach section: section.callMethod.edit()
        → section.saveData()
            → $axios.put(`/api/${endpoint}`, sectionData)
    → bulkRequest? handleBulkSave() : individual saves
```

### Custom Save (with `custom-save` + `@save`)

```html
<vuci-form config="basicstation" custom-save @save="handleSave">
```

When `custom-save` is set, the framework delegates saving entirely to the `@save` handler.
The handler receives `uciData` as argument.

> **⚠️ Warning**: Using `custom-save` may affect how the form tracks dirty state
> and whether the Save button appears. Only use when the standard PUT-based save
> doesn't work with your backend.

---

## Common Errors and Solutions

### `TypeError: e.some is not a function` in `awaitNetwork`

**Cause**: A section's `endpoints` prop is not an array (undefined, null, or wrong type).

**Fix**: Ensure every `vuci-named-section` and `vuci-typed-section` has:

```html
:endpoints="[{ endpoint: 'your/endpoint' }]"
```

The section's `awaitNetwork` computed uses optional chaining and is safe:

```javascript
awaitNetwork() {
  return this.endpoints?.some(t => t.awaitNetwork) || false
}
```

But the form's `handleBulkSave` does:

```javascript
const n = e.some(l => l.awaitNetwork);
```

If the sections array `e` contains undefined entries, this crashes.

### `TypeError: Cannot read properties of undefined (reading 'saveable')`

**Cause**: `vuciSections` contains a key whose value is undefined. This happens when
a section component is destroyed/unmounted but its key remains in the dictionary.

**Location**:

```javascript
// vuci-form computed
isSaveable() {
  return Object.values(this.vuciSections).some(e => e.saveable)
}
```

### 22 Empty Rows / Wrong Row Count

**Cause**: Section's `data()` computed returns `this.uciData[this.dataKey]`. If `dataKey`
doesn't match any key in `uciData`, or the API returns all config sections mixed together,
every section gets the same (wrong) data.

**Fix**: Each section must have a **unique `data-key`** and a **dedicated API endpoint**
that returns only the relevant sections.

---

## Complete BasicStation Example

```html
<template>
  <vuci-form config="basicstation" @save="handleSave">

    <!-- Named section: framework calls GET /api/basicstation/config/auth -->
    <vuci-named-section name="auth" title="Authentication" v-slot="{ s }"
      :endpoints="[{ endpoint: 'basicstation/config' }]" data-key="auth">
      <vuci-form-item-input :uci-section="s" label="Server" name="addr" />
      <vuci-form-item-input :uci-section="s" label="Port" name="port" />
    </vuci-named-section>

    <!-- Typed section: framework calls GET /api/basicstation/rfconf -->
    <vuci-typed-section type="rfconf" title="RF Configuration"
      :columns="[{ name: 'freq', label: 'Frequency' }]"
      :endpoints="[{ endpoint: 'basicstation/rfconf' }]" data-key="rfconf">
      <template #freq="{ s }">
        <vuci-form-item-input :uci-section="s" name="freq" />
      </template>
    </vuci-typed-section>

  </vuci-form>
</template>
```

---

## References

- [Teltonika Community: VUCI Vue Components](https://community.teltonika.lt/t/vuci-vue-components/15156)
- [VUCI Upstream Docs: Components](https://janenas-luk.github.io/vuci/uci/components.html)
- [UCI Command Usage](https://wiki.teltonika-networks.com/view/UCI_command_usage)
- Source: `vuci-ui-core/bin/vuci-ui-core/src/dist/www/assets/index-2026-01-21-135a9278bb8.js.gz`
