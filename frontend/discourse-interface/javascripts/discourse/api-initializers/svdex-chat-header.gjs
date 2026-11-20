import { action } from "@ember/object";
import { apiInitializer } from "discourse/lib/api";

const directMessagesUrl = "/chat/direct-messages";

const initializer = apiInitializer(api => {
  const chatIcon = api.headerIcons.resolve().find(entry => entry.key === "chat");
  if (!chatIcon) return;

  class DirectMessagesHeaderIcon extends chatIcon.value {
    get opensInbox() {
      return !this.chatStateManager.isFullPageActive || this.chatSeparateSidebarMode.never;
    }

    get targetUrl() {
      return this.opensInbox ? directMessagesUrl : super.targetUrl;
    }

    get title() {
      return this.opensInbox ? "Direct messages" : super.title;
    }

    @action openChat() {
      if (this.opensInbox) this.chatStateManager.prefersFullPage();
      return super.openChat();
    }
  }

  api.headerIcons.replace("chat", DirectMessagesHeaderIcon);
});

export default { ...initializer, after: ["inject-objects", "chat-setup"] };
