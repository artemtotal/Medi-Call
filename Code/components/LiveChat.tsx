/* eslint-disable camelcase */
"use client";

import { useEffect } from "react";

export default function LiveChat() {
  useEffect(() => {
    // Attach to the global window object so they are available for the script.
    window.Tawk_API = window.Tawk_API || {};
    window.Tawk_LoadStart = new Date();

    (function () {
      const s1 = document.createElement("script");
      const s0 = document.getElementsByTagName("script")[0];
      s1.async = true;
      s1.src = 'https://embed.tawk.to/67b86d764cb53c1906d281da/1ikk6n5rk';
      s1.charset = 'UTF-8';
      s1.setAttribute('crossorigin', '*');
      if (s0 && s0.parentNode) {
        s0.parentNode.insertBefore(s1, s0);
      }
    })();
  }, []);

  return null; // This component does not render any UI element.
}
/* eslint-enable camelcase */
