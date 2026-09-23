export const styles = `
      .pocknix-control-tabs {
        height: 95%;
        width: 316px;
        position: fixed;
        margin-top: -12px;
        margin-left: -8px;
        overflow: hidden;
      }
      .pocknix-control-tabs > div > div:first-child::before {
        background: #0D141C;
        box-shadow: none;
        backdrop-filter: none;
      }
      .pocknix-control-tabs [role="tabpanel"] {
        padding-left: 0 !important;
        padding-right: 0 !important;
      }
      .pocknix-control-tabs .pocknix-control-tab-content {
        padding-bottom: 24px;
      }
      .pocknix-control-tabs .pocknix-log {
        font-family: monospace;
        font-size: 10px;
        line-height: 14px;
        word-break: break-all;
        white-space: pre-wrap;
      }
      .pk-fan-graph {
        margin: 6px 16px 2px;
        padding: 4px;
        border-radius: 6px;
        border: 2px solid transparent;
      }
      .pocknix-control-tabs-modal .pk-fan-graph {
        max-width: 480px;
        margin: 4px auto;
      }
      .pk-fan-graph-focused {
        border-color: rgba(255,255,255,0.6);
      }
      .pk-fan-graph-editing {
        border-color: #ffd166;
      }
      .pk-fan-hint, .pocknix-control-tabs-modal .pocknix-note {
        padding: 4px 8px;
        font-size: 12px;
        line-height: 16px;
        opacity: 0.7;
      }
      .pk-fan-title {
        margin: 0 0 8px 16px;
        font-size: 18px;
      }
      .pk-fan-error {
        margin: 4px 16px;
        color: #ff6b6b;
        font-size: 12px;
      }
      .pocknix-control-tabs .pocknix-note {
        box-sizing: border-box;
        width: 100%;
        padding: 8px 16px 8px;
        font-size: 12px;
        line-height: 16px;
        opacity: 0.62;
        text-align: left;
        justify-content: flex-start;
        align-self: stretch;
      }
    `;
