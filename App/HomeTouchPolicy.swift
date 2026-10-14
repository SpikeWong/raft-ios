// PointerSensor also accepts touch. Let the Web's delayed TouchSensor own
// Sidebar touch sorting instead, without swallowing click or scroll defaults.
enum HomeTouchPolicy {
    static let script = #"""
    if (location.origin === new URL(raftHomeOrigin).origin) {
      document.addEventListener('pointerdown', event => {
        if (event.pointerType !== 'touch' || !(event.target instanceof Element)) return;
        const target = event.target;
        if (!target.closest('[data-sidebar-drag-item]')) return;
        if (target.closest('input,textarea,select,[contenteditable]:not([contenteditable="false"]),[aria-haspopup]:not([aria-haspopup="false"]),[data-slot="menu-trigger"]')) return;
        event.stopPropagation();
      }, {capture:true, passive:true});
    }
    """#
}
