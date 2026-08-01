# Phase 2: Rich Content & Author Profiles - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-14
**Phase:** 2-rich-content-author-profiles
**Areas discussed:** Inline image upload flow, Author legacy field & migration, Admin profile editing surface, Table controls & paragraph spacing CSS

---

## Inline Image Upload Flow

### Q1: How does the admin trigger an image insert?

| Option | Description | Selected |
|--------|-------------|----------|
| Toolbar button → hidden file picker | Image stub button activates, triggers hidden file input, direct-uploads to ActiveStorage | |
| Drag-and-drop into editor body | Admin drops image file directly onto editor | |
| Both: file picker + drag-and-drop | Full coverage — file picker button AND drop handler | ✓ |

**User's choice:** Both: file picker + drag-and-drop
**Notes:** Broader coverage preferred over simplicity here.

---

### Q2: While upload is in progress, what should the editor show?

| Option | Description | Selected |
|--------|-------------|----------|
| Placeholder node with spinner | Insert placeholder at cursor, replace with img on success | ✓ |
| Disable toolbar, insert on success | No in-editor feedback — disable button during upload | |
| You decide | Researcher picks | |

**User's choice:** Placeholder node with spinner
**Notes:** Standard Tiptap pattern — better UX for large images.

---

### Q3: What controls should admins have over inserted images?

| Option | Description | Selected |
|--------|-------------|----------|
| Alt text prompt + drag corner handles to resize | Prompt alt text at upload; drag handles for size; width attribute respected on render | ✓ |
| Alt text only, always full-width | Alt text prompt; no resize — all images 100% prose width | |
| No alt text, no resize | Minimal — just insert the image | |

**User's choice:** Alt text prompt + drag corner handles to resize
**Notes:** Width stored as attribute on img; capped by prose column on published page.

---

### Q4: Resize handles — how should admin control size?

| Option | Description | Selected |
|--------|-------------|----------|
| Drag corner handles | Standard WYSIWYG — corner handles; width as HTML attribute | ✓ |
| Width dropdown (25%, 50%, 75%, 100%) | Floating menu with preset sizes | |
| You decide | Researcher picks simplest approach | |

**User's choice:** Drag corner handles
**Notes:** Width attribute stored on img, respected on render capped by prose max-w.

---

### Q5: When the published post renders, how should inline images behave?

| Option | Description | Selected |
|--------|-------------|----------|
| Respect width attribute from editor | Width set by handles stored in img HTML; capped by prose column width | ✓ |
| Always full-width regardless of editor | Ignore width attribute; all images 100% prose width | |
| You decide | Researcher picks based on prose CSS | |

**User's choice:** Respect width attribute from editor
**Notes:** Consistent WYSIWYG — what you set in the editor is what you get on publish.

---

## Author Legacy Field & Migration

### Q1: What happens to existing posts with a plain-text author string?

| Option | Description | Selected |
|--------|-------------|----------|
| Keep string as legacy fallback | Show page: author_id wins; string shown only when no author_id | ✓ |
| Rake task: match strings to User full names | Migration tries first_name + last_name match | |
| Null out author string going forward | Admin must re-select for all posts; old values discarded | |

**User's choice:** Keep string as legacy fallback
**Notes:** No data loss; admin doesn't need to re-assign all existing posts.

---

### Q2: How should the author field work in the admin blog form?

| Option | Description | Selected |
|--------|-------------|----------|
| Replace text field with user dropdown | Remove text field; dropdown of admin users only | |
| Keep both fields (text field + user dropdown) | Both present; author_id dropdown added alongside existing text field | ✓ |
| Dropdown only, hide text field, add a clear button | Dropdown with Clear option; text field hidden | |

**User's choice:** Keep both fields (text field + user dropdown)
**Notes:** Preserves ability to enter freeform author names for historical/external authors.

---

### Q3: When both author_id and the text field have values, which shows on published post?

| Option | Description | Selected |
|--------|-------------|----------|
| author_id wins (User profile card shown) | If author_id set, show User card; text field ignored | ✓ |
| Text field wins | Render string; dropdown used for schema only | |
| Show both independently | Show card AND byline — redundant | |

**User's choice:** author_id wins
**Notes:** Clear priority rule — User association takes precedence when present.

---

## Admin Profile Editing Surface

### Q1: Where do admins edit their author profile?

| Option | Description | Selected |
|--------|-------------|----------|
| /admin/profile — current user edits own | New route, signs-in user only | |
| Admin/users CRUD — manage all user profiles | Full resource for all users | ✓ |
| Extend Devise edit registration path | Re-enable registrations or custom Devise route | |

**User's choice:** Admin/users CRUD — manage all user profiles
**Notes:** Full management surface chosen over per-user self-edit.

---

### Q2: What actions does the admin/users CRUD need?

| Option | Description | Selected |
|--------|-------------|----------|
| Index + Edit/Update only | List users, edit author profile fields only | |
| Full CRUD (index, show, new, create, edit, update, destroy) | Complete user management including create/delete | ✓ |
| Show + Edit/Update (no index) | Individual edit, no user listing | |

**User's choice:** Full CRUD
**Notes:** Broader than AUTH-02 requirements; includes user creation and deletion.

---

### Q3: When creating a new admin user from the UI, how is their password handled?

| Option | Description | Selected |
|--------|-------------|----------|
| Admin sets temporary password, user changes on first login | Admin enters password in form | ✓ |
| Auto-generate password + send Devise password reset email | Secure; requires email delivery configured | |
| You decide | Researcher picks standard Devise approach | |

**User's choice:** Admin sets temporary password
**Notes:** Simpler; assumes email delivery may not be configured in all environments.

---

## Table Controls & Paragraph Spacing CSS

### Q1: How should table row/col controls appear in the editor?

| Option | Description | Selected |
|--------|-------------|----------|
| Floating bubble menu | BubbleMenu appears when cursor is in table cell; add/remove row/col buttons | ✓ |
| Additional toolbar buttons (context-sensitive) | Toolbar shows table buttons when in table | |
| Right-click context menu | Standard spreadsheet UX; custom plugin required | |

**User's choice:** Floating bubble menu
**Notes:** Clean UX — controls appear contextually, not cluttering the main toolbar.

---

### Q2: How should 'Relaxed' paragraph spacing render on the published post?

| Option | Description | Selected |
|--------|-------------|----------|
| CSS class on prose container | prose-relaxed class; custom CSS for paragraph margin | ✓ |
| Inline style on prose container | style attribute with CSS variable | |
| Separate spacing stylesheet per value | Two pre-defined Tailwind classes | |

**User's choice:** CSS class on prose container
**Notes:** blogs.spacing column stores 'normal' or 'relaxed'; show page applies class conditionally.

---

### Q3: Where does the paragraph spacing dropdown appear in the admin form?

| Option | Description | Selected |
|--------|-------------|----------|
| In the form metadata section (near excerpt/category) | Standard select field; no JS needed | ✓ |
| In the Tiptap toolbar as a dropdown button | Editor toolbar; more Stimulus wiring | |
| You decide | Researcher picks placement | |

**User's choice:** Form metadata section
**Notes:** Consistent with other metadata fields; simpler implementation.

---

## Claude's Discretion

- Image placeholder spinner: inline SVG spinner vs CSS animation — researcher picks
- Avatar placeholder: initials extraction or generic SVG — researcher picks simplest
- Resize handles implementation: evaluate `@tiptap/extension-image` or community extension
- Table package set: `@tiptap/extension-table` + row + cell + header — researcher confirms
- User destroy: `dependent: :nullify` on blogs.author_id to prevent cascade delete

## Deferred Ideas

- Public author listing pages (`/authors/:slug`)
- Case studies editor migration
- Advanced image controls (captions, alignment, float)
- Email-based password setup flow for new admin users
