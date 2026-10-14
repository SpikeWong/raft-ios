// Compatibility for the Web composer's auto-height image drag handle.
// Keep the Web's chip dimensions and removal affordance; only fill the handle.
enum ComposerPreviewStyle {
    static let script = #"""
    if (location.origin === new URL(raftComposerOrigin).origin) {
      const id = 'raft-ios-composer-preview-style';
      if (!document.getElementById(id)) {
        const style = document.createElement('style');
        style.id = id;
        style.textContent = `
          [data-slot="composer-attachment"]:has([data-slot="composer-attachment-image"]) > [data-slot="tooltip-trigger"],
          [data-slot="composer-attachment"]:has([data-slot="composer-attachment-image"]) > div:has([data-slot="composer-attachment-image"]) {
            width: 100%;
            height: 100%;
          }
        `;
        document.head.append(style);
      }
    }
    """#
}
