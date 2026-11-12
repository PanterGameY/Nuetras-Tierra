# Custom Instructions for Nuestra Tierra Coding Agents

Always maintain UI/UX design consistency by following the Design System documented in:
- [diseño.md](file:///c:/Users/johan/OneDrive/Documentos/GitHub/nuestra-tierra-2.0/diseño.md)
- [manual_diseno_ui.md](file:///c:/Users/johan/OneDrive/Documentos/GitHub/nuestra-tierra-2.0/documentacion/interfaz_ui/manual_diseno_ui.md)

## Key Rules (Automotive Glassmorphism)
- **Glassmorphic Cockpit Theme**: Dark slate/carbon glass background (`Color(0.06, 0.07, 0.08, 0.85-0.95)`), cards (`Color(0.09, 0.10, 0.12, 0.90)`), and fine 1px frost metallic borders (`Color(0.78, 0.81, 0.85, 0.20-0.25)`).
- **Accents**: Automotive Instrument Amber (`Color(0.88, 0.68, 0.28, 0.92)`) for active states, routes, and selections. Technical Crimson (`Color(0.78, 0.28, 0.26, 0.95)`) for close/exit/emergency actions.
- **Mobile Readability**: Main panels minimum `1100x680` px. Typography hierarchy with `Moderniz.otf`: Titles `36-48px`, buttons `24-32px`, descriptions `22-28px`, telemetry `14-24px`.
- **Button Styling**: Glass buttons (`Color(0.08, 0.09, 0.11, 0.78)`), corner radius of `8-12px`, with amber or crimson pressed states and soft drop shadows (`shadow_size: 4-6px`).
- **Soft Transitions**: Modal dialogs and apps fade and scale in using Tweens (`scale` 0.92 to 1.0, `modulate:a` 0.0 to 1.0) over `0.25 - 0.35s` (`TRANS_BACK` / `TRANS_CUBIC`, `EASE_OUT`).
