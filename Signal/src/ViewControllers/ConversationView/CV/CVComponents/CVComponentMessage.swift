//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public class CVComponentMessage: CVComponentBase, CVRootComponent {

    public var cellReuseIdentifier: CVCellReuseIdentifier {
        .`default`
    }

    public var isDedicatedCell: Bool { false }

    private var bodyText: CVComponent?

    private var bodyMedia: CVComponent?

    private var senderName: CVComponent?

    private var senderAvatar: CVComponentState.SenderAvatar?
    private var hasSenderAvatarLayout: Bool {
        // Return true if space for a sender avatar appears in the layout.
        // Avatar itself might not appear due to de-duplication.
        isIncoming && isGroupThread && senderAvatar != nil && conversationStyle.type != .messageDetails
    }
    private var hasSenderAvatar: Bool {
        // Return true if a sender avatar appears.
        hasSenderAvatarLayout && itemViewState.shouldShowSenderAvatar
    }

    // This is the "standalone" footer, as opposed to
    // a footer overlaid over body media.
    private var standaloneFooter: CVComponentFooter?

    private var sticker: CVComponent?

    private var viewOnce: CVComponent?

    private var quotedReply: CVComponent?

    private var linkPreview: CVComponent?

    private var reactions: CVComponent?

    private var audioAttachment: CVComponent?

    private var genericAttachment: CVComponent?

    private var contactShare: CVComponent?

    private var bottomButtons: CVComponent?

    private var swipeActionProgress: CVMessageSwipeActionState.Progress?
    private var swipeActionReference: CVMessageSwipeActionState.Reference?

    private var hasSendFailureBadge = false

    override init(itemModel: CVItemModel) {
        super.init(itemModel: itemModel)

        buildComponentStates()
    }

    private var sharpCorners: OWSDirectionalRectCorner {

        var rawValue: UInt = 0

        if !itemViewState.isFirstInCluster {
            rawValue |= isIncoming ? OWSDirectionalRectCorner.topLeading.rawValue : OWSDirectionalRectCorner.topTrailing.rawValue
        }

        if !itemViewState.isLastInCluster {
            rawValue |= isIncoming ? OWSDirectionalRectCorner.bottomLeading.rawValue : OWSDirectionalRectCorner.bottomTrailing.rawValue
        }

        return OWSDirectionalRectCorner(rawValue: rawValue)
    }

    private var sharpCornersForQuotedMessage: OWSDirectionalRectCorner {
        if itemViewState.senderName != nil {
            return .allCorners
        } else {
            var rawValue = sharpCorners.rawValue
            rawValue |= OWSDirectionalRectCorner.bottomLeading.rawValue
            rawValue |= OWSDirectionalRectCorner.bottomTrailing.rawValue
            return OWSDirectionalRectCorner(rawValue: rawValue)
        }
    }

    private func subcomponent(forKey key: CVComponentKey) -> CVComponent? {
        switch key {
        case .senderName:
            return self.senderName
        case .bodyText:
            return self.bodyText
        case .bodyMedia:
            return self.bodyMedia
        case .footer:
            return self.standaloneFooter
        case .sticker:
            return self.sticker
        case .viewOnce:
            return self.viewOnce
        case .audioAttachment:
            return self.audioAttachment
        case .genericAttachment:
            return self.genericAttachment
        case .quotedReply:
            return self.quotedReply
        case .linkPreview:
            return self.linkPreview
        case .reactions:
            return self.reactions
        case .contactShare:
            return self.contactShare
        case .bottomButtons:
            return self.bottomButtons

        // We don't render sender avatars with a subcomponent.
        case .senderAvatar:
            return nil
        case .systemMessage, .dateHeader, .unreadIndicator, .typingIndicator, .threadDetails, .failedOrPendingDownloads, .sendFailureBadge:
            return nil
        }
    }

    private var canFooterOverlayMedia: Bool {
        hasBodyMediaWithThumbnail && !isBorderless
    }

    private var hasBodyMediaWithThumbnail: Bool {
        bodyMedia != nil
    }

    // TODO: We might want to render the "remotely deleted" indicator using a dedicated component.
    private var hasBodyText: Bool {
        if wasRemotelyDeleted {
            return true
        }

        return componentState.bodyText != nil
    }

    private var isBubbleTransparent: Bool {
        if wasRemotelyDeleted {
            return false
        } else if componentState.isSticker {
            return true
        } else if isBorderlessViewOnceMessage {
            return false
        } else {
            return isBorderless
        }
    }

    private var isBorderlessViewOnceMessage: Bool {
        guard let viewOnce = componentState.viewOnce else {
            return false
        }
        switch viewOnce.viewOnceState {
        case .unknown:
            owsFailDebug("Invalid value.")
            return true
        case .incomingExpired, .incomingInvalidContent:
            return true
        default:
            return false
        }
    }

    private var hasTapForMore: Bool {
        standaloneFooter?.hasTapForMore ?? false
    }

    private func buildComponentStates() {

        hasSendFailureBadge = componentState.sendFailureBadge != nil

        if let senderName = itemViewState.senderName {
            self.senderName = CVComponentSenderName(itemModel: itemModel, senderName: senderName)
        }
        if let senderAvatar = componentState.senderAvatar {
            self.senderAvatar = senderAvatar
        }
        if let stickerState = componentState.sticker {
            self.sticker = CVComponentSticker(itemModel: itemModel, sticker: stickerState)
        }
        if let viewOnceState = componentState.viewOnce {
            self.viewOnce = CVComponentViewOnce(itemModel: itemModel, viewOnce: viewOnceState)
        }
        if let audioAttachmentState = componentState.audioAttachment {
            self.audioAttachment = CVComponentAudioAttachment(itemModel: itemModel,
                                                              audioAttachment: audioAttachmentState)
        }
        if let genericAttachmentState = componentState.genericAttachment {
            self.genericAttachment = CVComponentGenericAttachment(itemModel: itemModel,
                                                                  genericAttachment: genericAttachmentState)
        }
        if let bodyTextState = itemViewState.bodyTextState {
            bodyText = CVComponentBodyText(itemModel: itemModel, bodyTextState: bodyTextState)
        }
        if let contactShareState = componentState.contactShare {
            contactShare = CVComponentContactShare(itemModel: itemModel,
                                                   contactShareState: contactShareState)
        }
        if let bottomButtonsState = componentState.bottomButtons {
            bottomButtons = CVComponentBottomButtons(itemModel: itemModel,
                                                     bottomButtonsState: bottomButtonsState)
        }

        var footerOverlay: CVComponentFooter?
        if let bodyMediaState = componentState.bodyMedia {
            let shouldFooterOverlayMedia = (bodyText == nil && !isBorderless && !itemViewState.shouldHideFooter && !hasTapForMore)
            if shouldFooterOverlayMedia {
                if let footerState = itemViewState.footerState {
                    footerOverlay = CVComponentFooter(itemModel: itemModel,
                                                      footerState: footerState,
                                                      isOverlayingMedia: true,
                                                      isOutsideBubble: false)
                } else {
                    owsFailDebug("Missing footerState.")
                }
            }

            bodyMedia = CVComponentBodyMedia(itemModel: itemModel, bodyMedia: bodyMediaState, footerOverlay: footerOverlay)
        }

        let hasStandaloneFooter = (footerOverlay == nil && !itemViewState.shouldHideFooter)
        if hasStandaloneFooter {
            if let footerState = itemViewState.footerState {
                self.standaloneFooter = CVComponentFooter(itemModel: itemModel,
                                                          footerState: footerState,
                                                          isOverlayingMedia: false,
                                                          isOutsideBubble: isBubbleTransparent)
            } else {
                owsFailDebug("Missing footerState.")
            }
        }

        if let quotedReplyState = componentState.quotedReply {
            self.quotedReply = CVComponentQuotedReply(itemModel: itemModel,
                                                      quotedReply: quotedReplyState,
                                                      sharpCornersForQuotedMessage: sharpCornersForQuotedMessage)
        }

        if let linkPreviewState = componentState.linkPreview {
            self.linkPreview = CVComponentLinkPreview(itemModel: itemModel,
                                                      linkPreviewState: linkPreviewState)
        }

        if let reactionsState = componentState.reactions {
            self.reactions = CVComponentReactions(itemModel: itemModel, reactions: reactionsState)
        }
    }

    public func configure(cellView: UIView,
                          cellMeasurement: CVCellMeasurement,
                          componentDelegate: CVComponentDelegate,
                          cellSelection: CVCellSelection,
                          messageSwipeActionState: CVMessageSwipeActionState,
                          componentView: CVComponentView) {

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return
        }

        configureForRendering(componentView: componentView,
                              cellMeasurement: cellMeasurement,
                              componentDelegate: componentDelegate)
        let rootView = componentView.rootView
        owsAssertDebug(cellView.layoutMargins == .zero)
        owsAssertDebug(cellView.subviews.isEmpty)
        owsAssertDebug(rootView.superview == nil)

        cellView.layoutMargins = cellLayoutMargins
        cellView.addSubview(rootView)
        rootView.autoPinEdge(toSuperviewEdge: .top)

        let bottomInset = reactions != nil ? reactionsVProtrusion : 0
        rootView.autoPinEdge(toSuperviewEdge: .bottom, withInset: bottomInset)

        self.swipeActionReference = nil
        self.swipeActionProgress = messageSwipeActionState.getProgress(interactionId: interaction.uniqueId)

        var leadingView: UIView?
        if isShowingSelectionUI {
            let selectionView = componentView.selectionView
            selectionView.isSelected = componentDelegate.cvc_isMessageSelected(interaction)
            cellView.addSubview(selectionView)
            selectionView.autoPinEdges(toSuperviewMarginsExcludingEdge: .trailing)
            leadingView = selectionView
        }

        if isIncoming {
            if let leadingView = leadingView {
                rootView.autoPinEdge(.leading, to: .trailing, of: leadingView, withOffset: selectionViewSpacing)
            } else {
                rootView.autoPinEdge(toSuperviewMargin: .leading)
            }
        } else if hasSendFailureBadge {
            // Send failures are rare, so it's cheaper to only build these views when we need them.
            let sendFailureBadge = UIImageView()
            sendFailureBadge.contentMode = .center
            sendFailureBadge.setTemplateImageName("error-outline-24", tintColor: .ows_accentRed)
            sendFailureBadge.autoSetDimensions(to: CGSize(square: sendFailureBadgeSize))
            cellView.addSubview(sendFailureBadge)
            sendFailureBadge.autoPinEdge(toSuperviewMargin: .trailing)

            if conversationStyle.hasWallpaper {
                sendFailureBadge.backgroundColor = conversationStyle.bubbleColor(isIncoming: true)
                sendFailureBadge.layer.cornerRadius = sendFailureBadgeSize / 2
                sendFailureBadge.clipsToBounds = true

                sendFailureBadge.autoPinEdge(.bottom, to: .bottom, of: rootView)
            } else {
                let sendFailureBadgeBottomMargin = round(conversationStyle.lastTextLineAxis - sendFailureBadgeSize * 0.5)
                sendFailureBadge.autoPinEdge(.bottom, to: .bottom, of: rootView, withOffset: -sendFailureBadgeBottomMargin)
            }

            rootView.autoPinEdge(.trailing, to: .leading, of: sendFailureBadge, withOffset: -sendFailureBadgeSpacing)
        } else {
            rootView.autoPinEdge(toSuperviewMargin: .trailing)
        }
    }

    public func buildComponentView(componentDelegate: CVComponentDelegate) -> CVComponentView {
        CVComponentViewMessage()
    }

    public static let textViewVSpacing: CGFloat = 2
    public static let bodyMediaQuotedReplyVSpacing: CGFloat = 6
    public static let quotedReplyTopMargin: CGFloat = 6

    private var selectionViewSpacing: CGFloat { ConversationStyle.messageStackSpacing }
    private var selectionViewWidth: CGFloat { ConversationStyle.selectionViewWidth }
    private var sendFailureBadgeSize: CGFloat { conversationStyle.hasWallpaper ? 40 : 24 }
    private var sendFailureBadgeSpacing: CGFloat { ConversationStyle.messageStackSpacing }

    // The "message" contents of this component are vertically
    // stacked in four sections.  Ordering of the keys in each
    // section determines the ordering of the subcomponents.
    private var topFullWidthCVComponentKeys: [CVComponentKey] { [.linkPreview] }
    private var topNestedCVComponentKeys: [CVComponentKey] { [.senderName] }
    private var bottomFullWidthCVComponentKeys: [CVComponentKey] { [.quotedReply, .bodyMedia] }
    private var bottomNestedCVComponentKeys: [CVComponentKey] { [.viewOnce, .audioAttachment, .genericAttachment, .contactShare, .bodyText, .footer] }

    public func configureForRendering(componentView: CVComponentView,
                                      cellMeasurement: CVCellMeasurement,
                                      componentDelegate: CVComponentDelegate) {
        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return
        }

        var outerAvatarView: AvatarImageView?
        var outerBubbleView: OWSBubbleView?

        if hasSenderAvatarLayout,
           let senderAvatar = self.senderAvatar {
            if hasSenderAvatar {
                componentView.avatarView.image = senderAvatar.senderAvatar
            }
            outerAvatarView = componentView.avatarView
        }

        func configureBubbleView() {
            let bubbleView = componentView.bubbleView
            bubbleView.backgroundColor = bubbleBackgroundColor
            bubbleView.sharpCorners = self.sharpCorners
            if let bubbleStrokeColor = self.bubbleStrokeColor {
                bubbleView.strokeColor = bubbleStrokeColor
                bubbleView.strokeThickness = 1
            } else {
                bubbleView.strokeColor = nil
                bubbleView.strokeThickness = 0
            }
            outerBubbleView = bubbleView
        }

        let outerContentView = configureContentStack(componentView: componentView,
                                                     cellMeasurement: cellMeasurement,
                                                     componentDelegate: componentDelegate)

        let stickerOverlaySubcomponent = subcomponent(forKey: .sticker)
        if nil == stickerOverlaySubcomponent {
            // TODO: We don't always use the bubble view for media.
            configureBubbleView()
        }

        var hInnerStackSubviews = [UIView]()
        if let subview = outerAvatarView {
            hInnerStackSubviews.append(subview)
        }

        let swipeActionContentView: UIView
        if let bubbleView = outerBubbleView {
            bubbleView.addSubview(outerContentView)
            bubbleView.ensureSubviewsFillBounds = true
            hInnerStackSubviews.append(bubbleView)
            swipeActionContentView = bubbleView

            if let componentAndView = findActiveComponentAndView(key: .bodyMedia,
                                                                 messageView: componentView) {
                if let bodyMediaComponent = componentAndView.component as? CVComponentBodyMedia {
                    if let bubbleViewPartner = bodyMediaComponent.bubbleViewPartner(componentView: componentAndView.componentView) {
                        bubbleView.addPartnerView(bubbleViewPartner)
                    }
                } else {
                    owsFailDebug("Invalid component.")
                }
            }
        } else {
            hInnerStackSubviews.append(outerContentView)
            swipeActionContentView = outerContentView
        }

        let hInnerStack = componentView.hInnerStack
        hInnerStack.reset()
        hInnerStack.configure(config: hInnerStackConfig,
                              cellMeasurement: cellMeasurement,
                              measurementKey: Self.measurementKey_hInnerStack,
                              subviews: hInnerStackSubviews)

        componentView.swipeActionContentView = swipeActionContentView
        let swipeToReplyIconView = componentView.swipeToReplyIconView
        swipeToReplyIconView.contentMode = .center
        swipeToReplyIconView.alpha = 0
        hInnerStack.addSubview(swipeToReplyIconView)
        hInnerStack.sendSubviewToBack(swipeToReplyIconView)
        swipeToReplyIconView.autoAlignAxis(.horizontal, toSameAxisOf: swipeActionContentView)
        swipeToReplyIconView.autoPinEdge(.leading, to: .leading, of: swipeActionContentView, withOffset: 8)

        if conversationStyle.hasWallpaper {
            swipeToReplyIconView.backgroundColor = conversationStyle.bubbleColor(isIncoming: true)
            swipeToReplyIconView.layer.cornerRadius = 17
            swipeToReplyIconView.clipsToBounds = true
            swipeToReplyIconView.autoSetDimensions(to: CGSize(square: 34))

            swipeToReplyIconView.setTemplateImageName("reply-outline-20",
                                                      tintColor: .ows_gray45)
        } else {
            swipeToReplyIconView.backgroundColor = .clear
            swipeToReplyIconView.layer.cornerRadius = 0
            swipeToReplyIconView.clipsToBounds = false
            swipeToReplyIconView.autoSetDimensions(to: CGSize(square: 24))

            swipeToReplyIconView.setTemplateImageName("reply-outline-24",
                                                      tintColor: .ows_gray45)
        }

        if let reactions = self.reactions {
            let reactionsView = configureSubcomponentView(messageView: componentView,
                                                          subcomponent: reactions,
                                                          cellMeasurement: cellMeasurement,
                                                          componentDelegate: componentDelegate,
                                                          key: .reactions)

            hInnerStack.addSubview(reactionsView.rootView)
            if isIncoming {
                reactionsView.rootView.autoPinEdge(.leading,
                                                   to: .leading,
                                                   of: outerContentView,
                                                   withOffset: +reactionsHInset,
                                                   relation: .greaterThanOrEqual)
            } else {
                reactionsView.rootView.autoPinEdge(.trailing,
                                                   to: .trailing,
                                                   of: outerContentView,
                                                   withOffset: -reactionsHInset,
                                                   relation: .lessThanOrEqual)
            }

            // We want the reaction bubbles to stick to the middle of the screen inset from
            // the edge of the bubble with a small amount of padding unless the bubble is smaller
            // than the reactions view in which case it will break these constraints and extend
            // further into the middle of the screen than the message itself.
            NSLayoutConstraint.autoSetPriority(.defaultLow) {
                if self.isIncoming {
                    reactionsView.rootView.autoPinEdge(.trailing,
                                                       to: .trailing,
                                                       of: outerContentView,
                                                       withOffset: -reactionsHInset)
                } else {
                    reactionsView.rootView.autoPinEdge(.leading,
                                                       to: .leading,
                                                       of: outerContentView,
                                                       withOffset: +reactionsHInset)
                }
            }

            reactionsView.rootView.autoPinEdge(.top,
                                               to: .bottom,
                                               of: outerContentView,
                                               withOffset: -reactionsVOverlap)
        }

        componentView.rootView.accessibilityLabel = buildAccessibilityLabel(componentView: componentView)
        componentView.rootView.isAccessibilityElement = true
    }

    private func configureContentStack(componentView: CVComponentViewMessage,
                                       cellMeasurement: CVCellMeasurement,
                                       componentDelegate: CVComponentDelegate) -> UIView {

        let topFullWidthSubcomponents = subcomponents(forKeys: topFullWidthCVComponentKeys)
        let topNestedSubcomponents = subcomponents(forKeys: topNestedCVComponentKeys)
        let bottomFullWidthSubcomponents = subcomponents(forKeys: bottomFullWidthCVComponentKeys)
        let bottomNestedSubcomponents = subcomponents(forKeys: bottomNestedCVComponentKeys)
        let stickerOverlaySubcomponent = subcomponent(forKey: .sticker)

        func configureStackView(_ stackView: ManualStackView,
                                stackConfig: CVStackViewConfig,
                                measurementKey: String,
                                componentKeys keys: [CVComponentKey]) -> ManualStackView {
            self.configureSubcomponentStack(messageView: componentView,
                                            stackView: stackView,
                                            stackConfig: stackConfig,
                                            cellMeasurement: cellMeasurement,
                                            measurementKey: measurementKey,
                                            componentDelegate: componentDelegate,
                                            keys: keys)
            return stackView
        }

        if nil != stickerOverlaySubcomponent {
            // Sticker message.
            //
            // Stack is borderless.
            //
            // Optional senderName and footer.
            return configureStackView(componentView.contentStack,
                                      stackConfig: buildBorderlessStackConfig(),
                                      measurementKey: Self.measurementKey_contentStack,
                                      componentKeys: [.senderName, .sticker, .footer])
        } else {
            // Has full-width components.

            var contentSubviews = [UIView]()

            if !topFullWidthSubcomponents.isEmpty {
                let stackConfig = buildFullWidthStackConfig(includeTopMargin: false)
                let topFullWidthStackView = configureStackView(componentView.topFullWidthStackView,
                                                               stackConfig: stackConfig,
                                                               measurementKey: Self.measurementKey_topFullWidthStackView,
                                                               componentKeys: topFullWidthCVComponentKeys)
                contentSubviews.append(topFullWidthStackView)
            }
            if !topNestedSubcomponents.isEmpty {
                let hasNeighborsAbove = !topFullWidthSubcomponents.isEmpty
                let hasNeighborsBelow = (!bottomFullWidthSubcomponents.isEmpty ||
                                            !bottomNestedSubcomponents.isEmpty ||
                                            nil != bottomButtons)
                let stackConfig = buildNestedStackConfig(hasNeighborsAbove: hasNeighborsAbove,
                                                         hasNeighborsBelow: hasNeighborsBelow)
                let topNestedStackView = configureStackView(componentView.topNestedStackView,
                                                            stackConfig: stackConfig,
                                                            measurementKey: Self.measurementKey_topNestedStackView,
                                                            componentKeys: topNestedCVComponentKeys)
                contentSubviews.append(topNestedStackView)
            }
            if !bottomFullWidthSubcomponents.isEmpty {
                // If a quoted reply is the top-most subcomponent,
                // apply a top margin.
                let applyTopMarginToFullWidthStack = (topFullWidthSubcomponents.isEmpty &&
                                                        topNestedSubcomponents.isEmpty &&
                                                        quotedReply != nil)
                let stackConfig = buildFullWidthStackConfig(includeTopMargin: applyTopMarginToFullWidthStack)
                let bottomFullWidthStackView = configureStackView(componentView.bottomFullWidthStackView,
                                                                  stackConfig: stackConfig,
                                                                  measurementKey: Self.measurementKey_bottomFullWidthStackView,
                                                                  componentKeys: bottomFullWidthCVComponentKeys)
                contentSubviews.append(bottomFullWidthStackView)
            }
            if !bottomNestedSubcomponents.isEmpty {
                let hasNeighborsAbove = (!topFullWidthSubcomponents.isEmpty ||
                                            !topNestedSubcomponents.isEmpty ||
                                            !bottomFullWidthSubcomponents.isEmpty)
                let hasNeighborsBelow = (nil != bottomButtons)
                let stackConfig = buildNestedStackConfig(hasNeighborsAbove: hasNeighborsAbove,
                                                         hasNeighborsBelow: hasNeighborsBelow)
                let bottomNestedStackView = configureStackView(componentView.bottomNestedStackView,
                                                               stackConfig: stackConfig,
                                                               measurementKey: Self.measurementKey_bottomNestedStackView,
                                                               componentKeys: bottomNestedCVComponentKeys)
                contentSubviews.append(bottomNestedStackView)
            }
            if nil != bottomButtons {
                if let componentAndView = configureSubcomponent(messageView: componentView,
                                                                cellMeasurement: cellMeasurement,
                                                                componentDelegate: componentDelegate,
                                                                key: .bottomButtons) {
                    let subview = componentAndView.componentView.rootView
                    contentSubviews.append(subview)
                } else {
                    owsFailDebug("Couldn't configure bottomButtons.")
                }
            }

            let contentStack = componentView.contentStack
            contentStack.reset()
            contentStack.configure(config: buildNoMarginsStackConfig(),
                                   cellMeasurement: cellMeasurement,
                                   measurementKey: Self.measurementKey_contentStack,
                                   subviews: contentSubviews)
            return contentStack
        }
    }

    // Builds an accessibility label for the entire message.
    // This label uses basic punctuation which might be used by
    // VoiceOver for pauses/timing.
    //
    // Example: Lilia sent: a picture, check out my selfie.
    // Example: You sent: great shot!
    private func buildAccessibilityLabel(componentView: CVComponentViewMessage) -> String {
        var elements = [String]()

        if isIncoming {
            if let accessibilityAuthorName = itemViewState.accessibilityAuthorName {
                let format = NSLocalizedString("CONVERSATION_VIEW_CELL_ACCESSIBILITY_SENDER_FORMAT",
                                               comment: "Format for sender info for accessibility label for message. Embeds {{ the sender name }}.")
                elements.append(String(format: format, accessibilityAuthorName))
            } else {
                owsFailDebug("Missing accessibilityAuthorName.")
            }
        } else if isOutgoing {
            elements.append(NSLocalizedString("CONVERSATION_VIEW_CELL_ACCESSIBILITY_SENDER_LOCAL_USER",
                                              comment: "Format for sender info for outgoing messages."))
        }

        // Order matters. For example, body media should be before body text.
        let accessibilityComponentKeys: [CVComponentKey] = [
            .bodyMedia,
            .bodyText,
            .sticker,
            .viewOnce,
            .audioAttachment,
            .genericAttachment,
            .contactShare
        ]
        var contents = [String]()
        for key in accessibilityComponentKeys {
            if let subcomponent = self.subcomponent(forKey: key) {
                if let accessibilityComponent = subcomponent as? CVAccessibilityComponent {
                    contents.append(accessibilityComponent.accessibilityDescription)
                } else {
                    owsFailDebug("Invalid accessibilityComponent.")
                }
            }
        }

        let timestampText = CVComponentFooter.timestampText(forInteraction: interaction,
                                                            shouldUseLongFormat: true)
        contents.append(timestampText)

        elements.append(contents.joined(separator: ", "))

        // NOTE: In the interest of keeping the accessibility label short,
        // we do not include information that is usually presented in the
        // following components:
        //
        // * footer (message send status, disappearing message status).
        //   We _do_ include time but not date. Dates are in the date headers.
        // * senderName
        // * senderAvatar
        // * quotedReply
        // * linkPreview
        // * reactions
        // * bottomButtons
        // * sendFailureBadge

        let result = elements.joined(separator: " ")
        return result
    }

    private var cellLayoutMargins: UIEdgeInsets {
        UIEdgeInsets(top: 0,
                     leading: conversationStyle.fullWidthGutterLeading,
                     bottom: 0,
                     trailing: conversationStyle.fullWidthGutterTrailing)
    }

    private var hInnerStackConfig: CVStackViewConfig {
        CVStackViewConfig(axis: .horizontal,
                          alignment: .bottom,
                          spacing: ConversationStyle.messageStackSpacing,
                          layoutMargins: .zero)
    }

    private let reactionsHInset: CGFloat = 6
    // The overlap between the message content and the reactions bubble.
    private var reactionsVOverlap: CGFloat {
        CVReactionCountsView.inset
    }
    // How far the reactions bubble protrudes below the message content.
    private var reactionsVProtrusion: CGFloat {
        let reactionsHeight = CVReactionCountsView.height
        return max(0, reactionsHeight - reactionsVOverlap)
    }

    private var bubbleBackgroundColor: UIColor {
        if !conversationStyle.hasWallpaper && (wasRemotelyDeleted || isBorderlessViewOnceMessage) {
            return Theme.backgroundColor
        }
        if isBubbleTransparent {
            return .clear
        }
        return itemModel.conversationStyle.bubbleColor(isIncoming: isIncoming)
    }

    private var bubbleStrokeColor: UIColor? {
        if wasRemotelyDeleted || isBorderlessViewOnceMessage {
            return conversationStyle.hasWallpaper ? nil : Theme.outlineColor
        } else {
            return nil
        }
    }

    private static let measurementKey_hInnerStack = "CVComponentMessage.measurementKey_hInnerStack"
    private static let measurementKey_contentStack = "CVComponentMessage.measurementKey_contentStack"
    private static let measurementKey_topFullWidthStackView = "CVComponentMessage.measurementKey_topFullWidthStackView"
    private static let measurementKey_topNestedStackView = "CVComponentMessage.measurementKey_topNestedStackView"
    private static let measurementKey_bottomFullWidthStackView = "CVComponentMessage.measurementKey_bottomFullWidthStackView"
    private static let measurementKey_bottomNestedStackView = "CVComponentMessage.measurementKey_bottomNestedStackView"

    public func measure(maxWidth maxWidthChatHistory: CGFloat, measurementBuilder: CVCellMeasurement.Builder) -> CGSize {
        owsAssertDebug(maxWidthChatHistory > 0)

        let outerStackViewMaxWidth = max(0, maxWidthChatHistory - cellLayoutMargins.totalWidth)
        var hInnerStackSize = CGSize.zero
        var outerStackViewSize: CGSize = .zero

        if hasSenderAvatarLayout {
            // Sender avatar in groups.
            outerStackViewSize.width += ConversationStyle.groupMessageAvatarDiameter + ConversationStyle.messageStackSpacing
            outerStackViewSize.height = max(outerStackViewSize.height, ConversationStyle.groupMessageAvatarDiameter)
        }
        if isShowingSelectionUI {
            outerStackViewSize.width += selectionViewWidth + selectionViewSpacing
        }
        if !isIncoming, hasSendFailureBadge {
            outerStackViewSize.width += sendFailureBadgeSize + sendFailureBadgeSpacing
        }
        // The message cell's "outer" stack can contain many views:
        // sender avatar, selection UI, send failure badge.
        // The message cell's "content" stack must fit within the
        // remaining space in the "outer" stack.
        let contentMaxWidth = max(0,
                                  min(conversationStyle.maxMessageWidth,
                                      outerStackViewMaxWidth - (outerStackViewSize.width +
                                                                    ConversationStyle.messageDirectionSpacing)))
        let contentStackSize = measureContentStack(maxWidth: contentMaxWidth,
                                                   measurementBuilder: measurementBuilder)
        outerStackViewSize.width += contentStackSize.width
        outerStackViewSize.height = max(outerStackViewSize.height, contentStackSize.height)

        //        var hInnerStackSubviews = [UIView]()
        //
        //        let hInnerStack = componentView.hInnerStack
        //        hInnerStack.reset()
        //        hInnerStack.configure(config: hInnerStackConfig,
        //                             cellMeasurement: cellMeasurement,
        //                             measurementKey: Self.measurementKey_hInnerStack,
        //                             subviews: hInnerStackSubviews)
        //
        var hInnerStackSubviewInfos = [ManualStackSubviewInfo]()
        if hasSenderAvatarLayout,
           nil != self.senderAvatar {
            // Sender avatar in groups.
            let avatarSize = CGSize.square(ConversationStyle.groupMessageAvatarDiameter)
            hInnerStackSubviewInfos.append(avatarSize.asManualSubviewInfo(hasFixedSize: true))
        }
        hInnerStackSubviewInfos.append(contentStackSize.asManualSubviewInfo(hasFixedWidth: true))
        let hInnerStackMeasurement = ManualStackView.measure(config: hInnerStackConfig,
                                                             measurementBuilder: measurementBuilder,
                                                             measurementKey: Self.measurementKey_hInnerStack,
                                                             subviewInfos: hInnerStackSubviewInfos)
        // TODO:
        //        return stackMeasurement.measuredSize

        hInnerStackSize.width += outerStackViewSize.width
        let minBubbleWidth = kOWSMessageCellCornerRadius_Large * 2
        hInnerStackSize.width = max(hInnerStackSize.width, minBubbleWidth)
        hInnerStackSize.height = max(hInnerStackSize.height, outerStackViewSize.height)

        if nil != reactions {
            hInnerStackSize.height += reactionsVProtrusion
        }

        return hInnerStackSize.ceil
    }

    private func measureContentStack(maxWidth contentMaxWidth: CGFloat,
                                     measurementBuilder: CVCellMeasurement.Builder) -> CGSize {

        func measure(stackConfig: CVStackViewConfig,
                     measurementKey: String,
                     componentKeys keys: [CVComponentKey]) -> CGSize {
            let maxWidth = contentMaxWidth - stackConfig.layoutMargins.totalWidth
            var subviewSizes = [CGSize]()
            for key in keys {
                guard let subcomponent = self.subcomponent(forKey: key) else {
                    // Not all subcomponents may be present.
                    continue
                }
                let subviewSize = subcomponent.measure(maxWidth: maxWidth,
                                                       measurementBuilder: measurementBuilder)
                subviewSizes.append(subviewSize)
            }
            let subviewInfos: [ManualStackSubviewInfo] = subviewSizes.map { subviewSize in
                (stackConfig.axis == .horizontal
                    ? subviewSize.asManualSubviewInfo(hasFixedWidth: true)
                    : subviewSize.asManualSubviewInfo(hasFixedHeight: true))
            }
            let stackMeasurement = ManualStackView.measure(config: stackConfig,
                                                           measurementBuilder: measurementBuilder,
                                                           measurementKey: measurementKey,
                                                           subviewInfos: subviewInfos)
            return stackMeasurement.measuredSize
        }

        let topFullWidthSubcomponents = subcomponents(forKeys: topFullWidthCVComponentKeys)
        let topNestedSubcomponents = subcomponents(forKeys: topNestedCVComponentKeys)
        let bottomFullWidthSubcomponents = subcomponents(forKeys: bottomFullWidthCVComponentKeys)
        let bottomNestedSubcomponents = subcomponents(forKeys: bottomNestedCVComponentKeys)
        let stickerOverlaySubcomponent = subcomponent(forKey: .sticker)

        if nil != stickerOverlaySubcomponent {
            // Sticker message.
            //
            // Stack is borderless.
            // Optional footer.
            return measure(stackConfig: buildBorderlessStackConfig(),
                           measurementKey: Self.measurementKey_contentStack,
                           componentKeys: [.senderName, .sticker, .footer])
        } else {
            // There are full-width components.
            // Use multiple stacks.

            var subviewSizes = [CGSize]()

            if !topFullWidthSubcomponents.isEmpty {
                let stackConfig = buildFullWidthStackConfig(includeTopMargin: false)
                subviewSizes.append(measure(stackConfig: stackConfig,
                                            measurementKey: Self.measurementKey_topFullWidthStackView,
                                            componentKeys: topFullWidthCVComponentKeys))
            }
            if !topNestedSubcomponents.isEmpty {
                let hasNeighborsAbove = !topFullWidthSubcomponents.isEmpty
                let hasNeighborsBelow = (!bottomFullWidthSubcomponents.isEmpty ||
                                            !bottomNestedSubcomponents.isEmpty ||
                                            nil != bottomButtons)
                let stackConfig = buildNestedStackConfig(hasNeighborsAbove: hasNeighborsAbove,
                                                         hasNeighborsBelow: hasNeighborsBelow)
                subviewSizes.append(measure(stackConfig: stackConfig,
                                            measurementKey: Self.measurementKey_topNestedStackView,
                                            componentKeys: topNestedCVComponentKeys))
            }
            if !bottomFullWidthSubcomponents.isEmpty {
                // If a quoted reply is the top-most subcomponent,
                // apply a top margin.
                let applyTopMarginToFullWidthStack = (topFullWidthSubcomponents.isEmpty &&
                                                        topNestedSubcomponents.isEmpty &&
                                                        quotedReply != nil)
                let stackConfig = buildFullWidthStackConfig(includeTopMargin: applyTopMarginToFullWidthStack)
                subviewSizes.append(measure(stackConfig: stackConfig,
                                            measurementKey: Self.measurementKey_bottomFullWidthStackView,
                                            componentKeys: bottomFullWidthCVComponentKeys))
            }
            if !bottomNestedSubcomponents.isEmpty {
                let hasNeighborsAbove = (!topFullWidthSubcomponents.isEmpty ||
                                            !topNestedSubcomponents.isEmpty ||
                                            !bottomFullWidthSubcomponents.isEmpty)
                let hasNeighborsBelow = (nil != bottomButtons)
                let stackConfig = buildNestedStackConfig(hasNeighborsAbove: hasNeighborsAbove,
                                                         hasNeighborsBelow: hasNeighborsBelow)
                subviewSizes.append(measure(stackConfig: stackConfig,
                                            measurementKey: Self.measurementKey_bottomNestedStackView,
                                            componentKeys: bottomNestedCVComponentKeys))
            }
            if let bottomButtons = bottomButtons {
                let subviewSize = bottomButtons.measure(maxWidth: contentMaxWidth,
                                                        measurementBuilder: measurementBuilder)
                subviewSizes.append(subviewSize)
            }

            let subviewInfos: [ManualStackSubviewInfo] = subviewSizes.map { subviewSize in
                subviewSize.asManualSubviewInfo(hasFixedHeight: true)
            }
            return ManualStackView.measure(config: buildNoMarginsStackConfig(),
                                           measurementBuilder: measurementBuilder,
                                           measurementKey: Self.measurementKey_contentStack,
                                           subviewInfos: subviewInfos).measuredSize
        }
    }

    // MARK: - Events

    public override func handleTap(sender: UITapGestureRecognizer,
                                   componentDelegate: CVComponentDelegate,
                                   componentView: CVComponentView,
                                   renderItem: CVRenderItem) -> Bool {

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return false
        }

        if isShowingSelectionUI {
            let selectionView = componentView.selectionView
            let itemViewModel = CVItemViewModelImpl(renderItem: renderItem)
            if componentDelegate.cvc_isMessageSelected(interaction) {
                selectionView.isSelected = false
                componentDelegate.cvc_didDeselectViewItem(itemViewModel)
            } else {
                selectionView.isSelected = true
                componentDelegate.cvc_didSelectViewItem(itemViewModel)
            }
            // Suppress other tap handling during selection mode.
            return true
        }

        if let outgoingMessage = interaction as? TSOutgoingMessage {
            switch outgoingMessage.messageState {
            case .failed:
                // Tap to retry.
                componentDelegate.cvc_didTapFailedOutgoingMessage(outgoingMessage)
                return true
            case .sending:
                // Ignore taps on outgoing messages being sent.
                return true
            default:
                break
            }
        }

        if hasSenderAvatar,
           componentView.avatarView.containsGestureLocation(sender) {
            componentDelegate.cvc_didTapSenderAvatar(interaction)
            return true
        }

        if let subcomponentAndView = findComponentAndView(sender: sender,
                                                          componentView: componentView) {
            let subcomponent = subcomponentAndView.component
            let subcomponentView = subcomponentAndView.componentView
            Logger.verbose("key: \(subcomponentAndView.key)")
            if subcomponent.handleTap(sender: sender,
                                      componentDelegate: componentDelegate,
                                      componentView: subcomponentView,
                                      renderItem: renderItem) {
                return true
            }
        }

        if let message = interaction as? TSMessage,
           nil != componentState.failedOrPendingDownloads {
            Logger.verbose("Retrying failed downloads.")
            componentDelegate.cvc_didTapFailedOrPendingDownloads(message)
            return true
        }

        return false
    }

    public override func findLongPressHandler(sender: UILongPressGestureRecognizer,
                                              componentDelegate: CVComponentDelegate,
                                              componentView: CVComponentView,
                                              renderItem: CVRenderItem) -> CVLongPressHandler? {

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return nil
        }

        if let subcomponentView = componentView.subcomponentView(key: .sticker),
           subcomponentView.rootView.containsGestureLocation(sender) {
            return CVLongPressHandler(delegate: componentDelegate,
                                      renderItem: renderItem,
                                      gestureLocation: .sticker)
        }
        if let subcomponentView = componentView.subcomponentView(key: .bodyMedia),
           subcomponentView.rootView.containsGestureLocation(sender) {
            return CVLongPressHandler(delegate: componentDelegate,
                                      renderItem: renderItem,
                                      gestureLocation: .media)
        }
        if let subcomponentView = componentView.subcomponentView(key: .audioAttachment),
           subcomponentView.rootView.containsGestureLocation(sender) {
            return CVLongPressHandler(delegate: componentDelegate,
                                      renderItem: renderItem,
                                      gestureLocation: .media)
        }
        if let subcomponentView = componentView.subcomponentView(key: .genericAttachment),
           subcomponentView.rootView.containsGestureLocation(sender) {
            return CVLongPressHandler(delegate: componentDelegate,
                                      renderItem: renderItem,
                                      gestureLocation: .media)
        }
        // TODO: linkPreview?
        if let subcomponentView = componentView.subcomponentView(key: .quotedReply),
           subcomponentView.rootView.containsGestureLocation(sender) {
            return CVLongPressHandler(delegate: componentDelegate,
                                      renderItem: renderItem,
                                      gestureLocation: .quotedReply)
        }

        return CVLongPressHandler(delegate: componentDelegate,
                                  renderItem: renderItem,
                                  gestureLocation: .`default`)
    }

    // For a configured & active cell, this will return the list of
    // currently active subcomponents & their corresponding subcomponent
    // views. This can be used for gesture dispatch, etc.
    private func findComponentAndView(sender: UIGestureRecognizer,
                                      componentView: CVComponentViewMessage) -> CVComponentAndView? {
        for subcomponentAndView in activeComponentAndViews(messageView: componentView) {
            let subcomponentView = subcomponentAndView.componentView
            let rootView = subcomponentView.rootView
            if rootView.containsGestureLocation(sender) {
                return subcomponentAndView
            }
        }
        return nil
    }

    // For a configured & active cell, this will return the list of
    // currently active subcomponents & their corresponding subcomponent
    // views. This can be used for gesture dispatch, etc.
    private func activeComponentAndViews(messageView: CVComponentViewMessage) -> [CVComponentAndView] {
        var result = [CVComponentAndView]()
        for key in CVComponentKey.allCases {
            guard let componentAndView = findActiveComponentAndView(key: key,
                                                                    messageView: messageView,
                                                                    ignoreMissing: true) else {
                continue
            }
            result.append(componentAndView)
        }
        return result
    }

    // For a configured & active cell, this will return a (component,
    // component view) tuple IFF that component is active.
    private func findActiveComponentAndView(key: CVComponentKey,
                                            messageView: CVComponentViewMessage,
                                            ignoreMissing: Bool = false) -> CVComponentAndView? {
        guard let subcomponent = self.subcomponent(forKey: key) else {
            // Not all subcomponents will be active.
            return nil
        }
        guard let subcomponentView = messageView.subcomponentView(key: key) else {
            if ignoreMissing {
                Logger.verbose("Missing subcomponentView: \(key).")
            } else {
                owsFailDebug("Missing subcomponentView.")
            }
            return nil
        }
        return CVComponentAndView(key: key, component: subcomponent, componentView: subcomponentView)
    }

    private func activeComponentKeys() -> Set<CVComponentKey> {
        Set(CVComponentKey.allCases.filter { key in
            nil != subcomponent(forKey: key)
        })
    }

    public func albumItemView(forAttachment attachment: TSAttachmentStream,
                              componentView: CVComponentView) -> UIView? {
        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return nil
        }
        guard let componentAndView = findActiveComponentAndView(key: .bodyMedia,
                                                                messageView: componentView) else {
            owsFailDebug("Missing bodyMedia subcomponent.")
            return nil
        }
        guard let bodyMediaComponent = componentAndView.component as? CVComponentBodyMedia else {
            owsFailDebug("Unexpected subcomponent.")
            return nil
        }
        let bodyMediaComponentView = componentAndView.componentView
        return bodyMediaComponent.albumItemView(forAttachment: attachment,
                                                componentView: bodyMediaComponentView)
    }

    // MARK: -

    // Used for rendering some portion of an Conversation View item.
    // It could be the entire item or some part thereof.
    @objc
    public class CVComponentViewMessage: NSObject, CVComponentView {

        // Contains the "outer" contents which are arranged horizontally:
        //
        // * Gutters
        // * Group sender bubble
        // * Content view wrapped in message bubble _or_ unwrapped content view.
        // * Reactions view, which uses a custom layout block.
        //
        // TODO:
        fileprivate let hInnerStack = ManualStackView(name: "hInnerStack")

        fileprivate let avatarView = AvatarImageView()

        fileprivate let bubbleView = OWSBubbleView()
        fileprivate let contentStack = ManualStackView(name: "contentStack")

        // We use these stack views when there is a mixture of subcomponents,
        // some of which are full-width and some of which are not.
        fileprivate let topFullWidthStackView = ManualStackView(name: "topFullWidthStackView")
        fileprivate let topNestedStackView = ManualStackView(name: "topNestedStackView")
        fileprivate let bottomFullWidthStackView = ManualStackView(name: "bottomFullWidthStackView")
        fileprivate let bottomNestedStackView = ManualStackView(name: "bottomNestedStackView")

        // TODO:
        fileprivate let selectionView = MessageSelectionView()

        fileprivate var swipeActionContentView: UIView?

        fileprivate let swipeToReplyIconView = UIImageView()

        public var isDedicatedCellView = false

        // TODO:
        public var rootView: UIView {
            hInnerStack
        }

        // MARK: - Subcomponents

        var senderNameView: CVComponentView?
        var bodyTextView: CVComponentView?
        var bodyMediaView: CVComponentView?
        var footerView: CVComponentView?
        var stickerView: CVComponentView?
        var viewOnceView: CVComponentView?
        var quotedReplyView: CVComponentView?
        var linkPreviewView: CVComponentView?
        var reactionsView: CVComponentView?
        var audioAttachmentView: CVComponentView?
        var genericAttachmentView: CVComponentView?
        var contactShareView: CVComponentView?
        var bottomButtonsView: CVComponentView?

        private var allSubcomponentViews: [CVComponentView] {
            [senderNameView, bodyTextView, bodyMediaView, footerView, stickerView, quotedReplyView, linkPreviewView, reactionsView, viewOnceView, audioAttachmentView, genericAttachmentView, contactShareView, bottomButtonsView].compactMap { $0 }
        }

        fileprivate func subcomponentView(key: CVComponentKey) -> CVComponentView? {
            switch key {
            case .senderName:
                return senderNameView
            case .bodyText:
                return bodyTextView
            case .bodyMedia:
                return bodyMediaView
            case .footer:
                return footerView
            case .sticker:
                return stickerView
            case .viewOnce:
                return viewOnceView
            case .quotedReply:
                return quotedReplyView
            case .linkPreview:
                return linkPreviewView
            case .reactions:
                return reactionsView
            case .audioAttachment:
                return audioAttachmentView
            case .genericAttachment:
                return genericAttachmentView
            case .contactShare:
                return contactShareView
            case .bottomButtons:
                return bottomButtonsView

            // We don't render sender avatars with a subcomponent.
            case .senderAvatar:
                owsFailDebug("Invalid component key: \(key)")
                return nil
            case .systemMessage, .dateHeader, .unreadIndicator, .typingIndicator, .threadDetails, .failedOrPendingDownloads, .sendFailureBadge:
                owsFailDebug("Invalid component key: \(key)")
                return nil
            }
        }

        fileprivate func setSubcomponentView(key: CVComponentKey, subcomponentView: CVComponentView?) {
            switch key {
            case .senderName:
                senderNameView = subcomponentView
            case .bodyText:
                bodyTextView = subcomponentView
            case .bodyMedia:
                bodyMediaView = subcomponentView
            case .footer:
                footerView = subcomponentView
            case .sticker:
                stickerView = subcomponentView
            case .viewOnce:
                viewOnceView = subcomponentView
            case .quotedReply:
                quotedReplyView = subcomponentView
            case .linkPreview:
                linkPreviewView = subcomponentView
            case .reactions:
                reactionsView = subcomponentView
            case .audioAttachment:
                audioAttachmentView = subcomponentView
            case .genericAttachment:
                genericAttachmentView = subcomponentView
            case .contactShare:
                contactShareView = subcomponentView
            case .bottomButtons:
                bottomButtonsView = subcomponentView

            // We don't render sender avatars with a subcomponent.
            case .senderAvatar:
                owsAssertDebug(subcomponentView == nil)
            case .systemMessage, .dateHeader, .unreadIndicator, .typingIndicator, .threadDetails, .failedOrPendingDownloads, .sendFailureBadge:
                owsAssertDebug(subcomponentView == nil)
            }
        }

        // MARK: -

        override required init() {
            avatarView.autoSetDimensions(to: CGSize(square: ConversationStyle.groupMessageAvatarDiameter))

            bubbleView.layoutMargins = .zero
        }

        public func setIsCellVisible(_ isCellVisible: Bool) {
            for subcomponentView in allSubcomponentViews {
                subcomponentView.setIsCellVisible(isCellVisible)
            }
        }

        public func reset() {
            removeSwipeActionAnimations()

            if !isDedicatedCellView {
                hInnerStack.reset()
                bubbleView.removeAllSubviews()
                contentStack.reset()
                topFullWidthStackView.reset()
                topNestedStackView.reset()
                bottomFullWidthStackView.reset()
                bottomNestedStackView.reset()
            }

            avatarView.image = nil

            bubbleView.clearPartnerViews()

            if !isDedicatedCellView {
                swipeActionContentView = nil
                swipeToReplyIconView.image = nil
            }
            swipeToReplyIconView.alpha = 0

            // We use hInnerStack.frame to detect whether or not
            // the cell has been laid out yet. Therefore we clear it here.
            hInnerStack.frame = .zero

            if isDedicatedCellView {
                for subcomponentView in allSubcomponentViews {
                    subcomponentView.isDedicatedCellView = true
                }
            }

            for subcomponentView in allSubcomponentViews {
                subcomponentView.reset()
            }

            if !isDedicatedCellView {
                for key in CVComponentKey.allCases {
                    // Don't clear bodyTextView; it is expensive to build.
                    if key != .bodyText {
                        self.setSubcomponentView(key: key, subcomponentView: nil)
                    }
                }
            }
        }

        fileprivate func removeSwipeActionAnimations() {
            swipeActionContentView?.layer.removeAllAnimations()
            avatarView.layer.removeAllAnimations()
            swipeToReplyIconView.layer.removeAllAnimations()
            reactionsView?.rootView.layer.removeAllAnimations()
        }
    }

    // MARK: - Swipe To Reply

    public override func findPanHandler(sender: UIPanGestureRecognizer,
                                        componentDelegate: CVComponentDelegate,
                                        componentView: CVComponentView,
                                        renderItem: CVRenderItem,
                                        messageSwipeActionState: CVMessageSwipeActionState) -> CVPanHandler? {
        AssertIsOnMainThread()

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return nil
        }

        if let audioAttachment = self.audioAttachment,
           let subcomponentView = componentView.subcomponentView(key: .audioAttachment),
           subcomponentView.rootView.containsGestureLocation(sender),
           let panHandler = audioAttachment.findPanHandler(sender: sender,
                                                           componentDelegate: componentDelegate,
                                                           componentView: subcomponentView,
                                                           renderItem: renderItem,
                                                           messageSwipeActionState: messageSwipeActionState) {
            return panHandler
        }

        tryToUpdateSwipeActionReference(componentView: componentView,
                                        renderItem: renderItem,
                                        messageSwipeActionState: messageSwipeActionState)
        guard swipeActionReference != nil else {
            owsFailDebug("Missing reference[\(renderItem.interactionUniqueId)].")
            return nil
        }

        return CVPanHandler(delegate: componentDelegate,
                            panType: .messageSwipeAction,
                            renderItem: renderItem)
    }

    public override func startPanGesture(sender: UIPanGestureRecognizer,
                                         panHandler: CVPanHandler,
                                         componentDelegate: CVComponentDelegate,
                                         componentView: CVComponentView,
                                         renderItem: CVRenderItem,
                                         messageSwipeActionState: CVMessageSwipeActionState) {
        AssertIsOnMainThread()

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return
        }
        owsAssertDebug(sender.state == .began)

        switch panHandler.panType {
        case .scrubAudio:
            guard let audioAttachment = self.audioAttachment,
                  let subcomponentView = componentView.subcomponentView(key: .audioAttachment) else {
                owsFailDebug("Missing audio attachment component.")
                return
            }
            audioAttachment.startPanGesture(sender: sender,
                                            panHandler: panHandler,
                                            componentDelegate: componentDelegate,
                                            componentView: subcomponentView,
                                            renderItem: renderItem,
                                            messageSwipeActionState: messageSwipeActionState)
        case .messageSwipeAction:
            tryToUpdateSwipeActionReference(componentView: componentView,
                                            renderItem: renderItem,
                                            messageSwipeActionState: messageSwipeActionState)
            updateSwipeActionProgress(sender: sender,
                                      panHandler: panHandler,
                                      componentDelegate: componentDelegate,
                                      renderItem: renderItem,
                                      componentView: componentView,
                                      messageSwipeActionState: messageSwipeActionState,
                                      hasFinished: false)
            tryToApplySwipeAction(componentView: componentView, isAnimated: false)
        }
    }

    public override func handlePanGesture(sender: UIPanGestureRecognizer,
                                          panHandler: CVPanHandler,
                                          componentDelegate: CVComponentDelegate,
                                          componentView: CVComponentView,
                                          renderItem: CVRenderItem,
                                          messageSwipeActionState: CVMessageSwipeActionState) {
        AssertIsOnMainThread()

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return
        }

        switch panHandler.panType {
        case .scrubAudio:
            guard let audioAttachment = self.audioAttachment,
                  let subcomponentView = componentView.subcomponentView(key: .audioAttachment) else {
                owsFailDebug("Missing audio attachment component.")
                return
            }
            audioAttachment.handlePanGesture(sender: sender,
                                             panHandler: panHandler,
                                             componentDelegate: componentDelegate,
                                             componentView: subcomponentView,
                                             renderItem: renderItem,
                                             messageSwipeActionState: messageSwipeActionState)
        case .messageSwipeAction:
            let hasFinished: Bool
            switch sender.state {
            case .changed:
                hasFinished = false
            case .ended:
                hasFinished = true
            default:
                clearSwipeAction(componentView: componentView,
                                 renderItem: renderItem,
                                 messageSwipeActionState: messageSwipeActionState,
                                 isAnimated: false)
                return
            }
            updateSwipeActionProgress(sender: sender,
                                      panHandler: panHandler,
                                      componentDelegate: componentDelegate,
                                      renderItem: renderItem,
                                      componentView: componentView,
                                      messageSwipeActionState: messageSwipeActionState,
                                      hasFinished: hasFinished)
            let hasFailed = [.failed, .cancelled].contains(sender.state)
            let isAnimated = !hasFailed
            tryToApplySwipeAction(componentView: componentView, isAnimated: isAnimated)
            if sender.state == .ended {
                clearSwipeAction(componentView: componentView,
                                 renderItem: renderItem,
                                 messageSwipeActionState: messageSwipeActionState,
                                 isAnimated: true)
            }
        }
    }

    public override func cellDidLayoutSubviews(componentView: CVComponentView,
                                               renderItem: CVRenderItem,
                                               messageSwipeActionState: CVMessageSwipeActionState) {
        AssertIsOnMainThread()

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return
        }
        tryToUpdateSwipeActionReference(componentView: componentView,
                                        renderItem: renderItem,
                                        messageSwipeActionState: messageSwipeActionState)
        tryToApplySwipeAction(componentView: componentView, isAnimated: false)
    }

    public override func cellDidBecomeVisible(componentView: CVComponentView,
                                              renderItem: CVRenderItem,
                                              messageSwipeActionState: CVMessageSwipeActionState) {
        AssertIsOnMainThread()

        guard let componentView = componentView as? CVComponentViewMessage else {
            owsFailDebug("Unexpected componentView.")
            return
        }
        tryToUpdateSwipeActionReference(componentView: componentView,
                                        renderItem: renderItem,
                                        messageSwipeActionState: messageSwipeActionState)
        tryToApplySwipeAction(componentView: componentView, isAnimated: false)
    }

    private func tryToUpdateSwipeActionReference(componentView: CVComponentViewMessage,
                                                 renderItem: CVRenderItem,
                                                 messageSwipeActionState: CVMessageSwipeActionState) {
        AssertIsOnMainThread()

        guard swipeActionReference == nil else {
            // Reference already set.
            return
        }

        guard let contentView = componentView.swipeActionContentView else {
            owsFailDebug("Missing outerContentView.")
            return
        }
        let avatarView = componentView.avatarView
        let iconView = componentView.swipeToReplyIconView
        let hInnerStack = componentView.hInnerStack

        let contentViewCenter = contentView.center
        let avatarViewCenter = avatarView.center
        let iconViewCenter = iconView.center
        guard hInnerStack.frame != .zero else {
            // Cell has not been laid out yet.
            return
        }
        var reactionsViewCenter: CGPoint?
        if let reactionsView = componentView.reactionsView {
            reactionsViewCenter = reactionsView.rootView.center
        }
        let reference = CVMessageSwipeActionState.Reference(contentViewCenter: contentViewCenter,
                                                            reactionsViewCenter: reactionsViewCenter,
                                                            avatarViewCenter: avatarViewCenter,
                                                            iconViewCenter: iconViewCenter)
        self.swipeActionReference = reference
    }

    private let swipeActionOffsetThreshold: CGFloat = 55

    private func updateSwipeActionProgress(
        sender: UIPanGestureRecognizer,
        panHandler: CVPanHandler,
        componentDelegate: CVComponentDelegate,
        renderItem: CVRenderItem,
        componentView: CVComponentViewMessage,
        messageSwipeActionState: CVMessageSwipeActionState,
        hasFinished: Bool
    ) {
        AssertIsOnMainThread()

        var xOffset = sender.translation(in: componentView.rootView).x
        var xVelocity = sender.velocity(in: componentView.rootView).x

        // Invert positions for RTL logic, since the user is swiping in the opposite direction.
        if CurrentAppContext().isRTL {
            xOffset = -xOffset
            xVelocity = -xVelocity
        }

        let hasFailed = [.failed, .cancelled].contains(sender.state)
        let storedOffset = (hasFailed || hasFinished) ? 0 : xOffset
        let progress = CVMessageSwipeActionState.Progress(xOffset: storedOffset)
        messageSwipeActionState.setProgress(
            interactionId: renderItem.interactionUniqueId,
            progress: progress
        )
        self.swipeActionProgress = progress

        let swipeToReplyIconView = componentView.swipeToReplyIconView

        let previousActiveDirection = panHandler.activeDirection
        let activeDirection: CVPanHandler.ActiveDirection
        switch xOffset {
        case let x where x >= swipeActionOffsetThreshold:
            // We're doing a message swipe action. We should
            // only become active if this message allows
            // swipe-to-reply.
            let itemViewModel = CVItemViewModelImpl(renderItem: renderItem)
            if componentDelegate.cvc_shouldAllowReplyForItem(itemViewModel) {
                activeDirection = .right
            } else {
                activeDirection = .none
            }
        case let x where x <= -swipeActionOffsetThreshold:
            activeDirection = .left
        default:
            activeDirection = .none
        }

        let didChangeActiveDirection = previousActiveDirection != activeDirection

        panHandler.activeDirection = activeDirection

        // Play a haptic when moving to active.
        if didChangeActiveDirection {
            switch activeDirection {
            case .right:
                ImpactHapticFeedback.impactOccured(style: .light)
                panHandler.percentDrivenTransition?.cancel()
                panHandler.percentDrivenTransition = nil
            case .left:
                ImpactHapticFeedback.impactOccured(style: .light)
                panHandler.percentDrivenTransition = UIPercentDrivenInteractiveTransition()
                componentDelegate.cvc_didTapShowMessageDetail(CVItemViewModelImpl(renderItem: renderItem))
            case .none:
                panHandler.percentDrivenTransition?.cancel()
                panHandler.percentDrivenTransition = nil
            }
        }

        // Update the reply image styling to reflect active state
        let isStarting = sender.state == .began
        if isStarting {
            // Prepare the message detail view as soon as we start doing
            // any gesture, we may or may not want to present it.
            componentDelegate.cvc_prepareMessageDetailForInteractivePresentation(CVItemViewModelImpl(renderItem: renderItem))
        }

        if isStarting || didChangeActiveDirection {
            let shouldAnimate = didChangeActiveDirection
            let transform: CGAffineTransform
            let tintColor: UIColor
            if activeDirection == .right {
                transform = CGAffineTransform(scaleX: 1.16, y: 1.16)
                tintColor = isDarkThemeEnabled ? .ows_gray25 : .ows_gray75
            } else {
                transform = .identity
                tintColor = .ows_gray45
            }
            swipeToReplyIconView.layer.removeAllAnimations()
            swipeToReplyIconView.tintColor = tintColor
            if shouldAnimate {
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0,
                    usingSpringWithDamping: 0.06,
                    initialSpringVelocity: 0.8,
                    options: [.curveEaseInOut, .beginFromCurrentState],
                    animations: {
                        swipeToReplyIconView.transform = transform
                    },
                    completion: nil
                )
            } else {
                swipeToReplyIconView.transform = transform
            }
        }

        if hasFinished {
            switch activeDirection {
            case .left:
                guard let percentDrivenTransition = panHandler.percentDrivenTransition else {
                    return owsFailDebug("Missing percentDrivenTransition")
                }
                // Only finish the pan if we're actively moving in
                // the correct direction.
                if xVelocity <= 0 {
                    percentDrivenTransition.finish()
                } else {
                    percentDrivenTransition.cancel()
                }
            case .right:
                let itemViewModel = CVItemViewModelImpl(renderItem: renderItem)
                componentDelegate.cvc_didTapReplyToItem(itemViewModel)
            case .none:
                break
            }
        } else if activeDirection == .left {
            guard let percentDrivenTransition = panHandler.percentDrivenTransition else {
                return owsFailDebug("Missing percentDrivenTransition")
            }
            let viewXOffset = sender.translation(in: componentDelegate.view).x
            let percentDriventTransitionProgress =
                (abs(viewXOffset) - swipeActionOffsetThreshold) / (componentDelegate.view.width - swipeActionOffsetThreshold)
            percentDrivenTransition.update(percentDriventTransitionProgress)
        }
    }

    private func tryToApplySwipeAction(
        componentView: CVComponentViewMessage,
        isAnimated: Bool
    ) {
        AssertIsOnMainThread()

        guard let contentView = componentView.swipeActionContentView else {
            owsFailDebug("Missing outerContentView.")
            return
        }
        guard let swipeActionReference = swipeActionReference,
              let swipeActionProgress = swipeActionProgress else {
            return
        }
        let swipeToReplyIconView = componentView.swipeToReplyIconView
        let avatarView = componentView.avatarView
        let iconView = componentView.swipeToReplyIconView

        // Scale the translation above or below the desired range,
        // to produce an elastic feeling when you overscroll.
        var alpha = swipeActionProgress.xOffset

        let isSwipingLeft = alpha < 0

        if isSwipingLeft, alpha < -swipeActionOffsetThreshold {
            // If we're swiping left, stop moving the message
            // after we reach the threshold.
            alpha = -swipeActionOffsetThreshold
        } else if alpha > swipeActionOffsetThreshold {
            let overflow = alpha - swipeActionOffsetThreshold
            alpha = swipeActionOffsetThreshold + overflow / 4
        }
        let position = CurrentAppContext().isRTL ? -alpha : alpha

        let slowPosition: CGFloat
        if isSwipingLeft {
            slowPosition = position
        } else {
            // When swiping right (swipe-to-reply) the swipe content moves at
            // 1/8th the speed of the message bubble, so that it reveals itself
            // from underneath with an elastic feel.
            slowPosition = position / 8
        }

        var iconAlpha: CGFloat = 1
        let useSwipeFadeTransition = isBorderless
        if useSwipeFadeTransition {
            iconAlpha = CGFloatInverseLerp(alpha, 0, swipeActionOffsetThreshold).clamp01()
        }

        let animations = {
            swipeToReplyIconView.alpha = iconAlpha
            contentView.center = swipeActionReference.contentViewCenter.plusX(position)
            avatarView.center = swipeActionReference.avatarViewCenter.plusX(slowPosition)
            iconView.center = swipeActionReference.iconViewCenter.plusX(slowPosition)
            if let reactionsViewCenter = swipeActionReference.reactionsViewCenter,
               let reactionsView = componentView.reactionsView {
                reactionsView.rootView.center = reactionsViewCenter.plusX(position)
            }
        }
        if isAnimated {
            UIView.animate(withDuration: 0.1,
                           delay: 0,
                           options: [.beginFromCurrentState],
                           animations: animations,
                           completion: nil)
        } else {
            componentView.removeSwipeActionAnimations()
            animations()
        }
    }

    private func clearSwipeAction(componentView: CVComponentViewMessage,
                                  renderItem: CVRenderItem,
                                  messageSwipeActionState: CVMessageSwipeActionState,
                                  isAnimated: Bool) {
        AssertIsOnMainThread()

        messageSwipeActionState.resetProgress(interactionId: renderItem.interactionUniqueId)

        guard let contentView = componentView.swipeActionContentView else {
            owsFailDebug("Missing outerContentView.")
            return
        }
        let avatarView = componentView.avatarView
        let iconView = componentView.swipeToReplyIconView
        guard let swipeActionReference = swipeActionReference else {
            return
        }

        let animations = {
            contentView.center = swipeActionReference.contentViewCenter
            avatarView.center = swipeActionReference.avatarViewCenter
            iconView.center = swipeActionReference.iconViewCenter
            iconView.alpha = 0

            if let reactionsViewCenter = swipeActionReference.reactionsViewCenter,
               let reactionsView = componentView.reactionsView {
                reactionsView.rootView.center = reactionsViewCenter
            }
        }

        if isAnimated {
            UIView.animate(withDuration: 0.2, animations: animations)
        } else {
            componentView.removeSwipeActionAnimations()
            animations()
        }

        self.swipeActionProgress = nil
    }
}

// MARK: -

fileprivate extension CVComponentMessage {

    func configureSubcomponentView(messageView: CVComponentViewMessage,
                                   subcomponent: CVComponent,
                                   cellMeasurement: CVCellMeasurement,
                                   componentDelegate: CVComponentDelegate,
                                   key: CVComponentKey) -> CVComponentView {
        if let subcomponentView = messageView.subcomponentView(key: key) {
            subcomponent.configureForRendering(componentView: subcomponentView,
                                               cellMeasurement: cellMeasurement,
                                               componentDelegate: componentDelegate)
            // TODO: Pin to measured height?
            return subcomponentView
        } else {
            let subcomponentView = subcomponent.buildComponentView(componentDelegate: componentDelegate)
            messageView.setSubcomponentView(key: key, subcomponentView: subcomponentView)
            subcomponent.configureForRendering(componentView: subcomponentView,
                                               cellMeasurement: cellMeasurement,
                                               componentDelegate: componentDelegate)
            // TODO: Pin to measured height?
            return subcomponentView
        }
    }

    func configureSubcomponent(messageView: CVComponentViewMessage,
                               cellMeasurement: CVCellMeasurement,
                               componentDelegate: CVComponentDelegate,
                               key: CVComponentKey) -> CVComponentAndView? {
        guard let subcomponent = self.subcomponent(forKey: key) else {
            return nil
        }
        let subcomponentView = configureSubcomponentView(messageView: messageView,
                                                         subcomponent: subcomponent,
                                                         cellMeasurement: cellMeasurement,
                                                         componentDelegate: componentDelegate,
                                                         key: key)
        return CVComponentAndView(key: key, component: subcomponent, componentView: subcomponentView)
    }

    func buildNestedStackConfig(hasNeighborsAbove: Bool,
                                hasNeighborsBelow: Bool) -> CVStackViewConfig {
        var layoutMargins = conversationStyle.textInsets
        if hasNeighborsAbove {
            layoutMargins.top = Self.textViewVSpacing
        }
        if hasNeighborsBelow {
            layoutMargins.bottom = Self.textViewVSpacing
        }
        return CVStackViewConfig(axis: .vertical,
                                 alignment: .fill,
                                 spacing: Self.textViewVSpacing,
                                 layoutMargins: layoutMargins)
    }

    func buildBorderlessStackConfig() -> CVStackViewConfig {
        buildNoMarginsStackConfig()
    }

    func buildFullWidthStackConfig(includeTopMargin: Bool) -> CVStackViewConfig {
        var layoutMargins = UIEdgeInsets.zero
        if includeTopMargin {
            layoutMargins.top = conversationStyle.textInsets.top
        }
        return CVStackViewConfig(axis: .vertical,
                                 alignment: .fill,
                                 spacing: Self.textViewVSpacing,
                                 layoutMargins: layoutMargins)
    }

    func buildNoMarginsStackConfig() -> CVStackViewConfig {
        CVStackViewConfig(axis: .vertical,
                          alignment: .fill,
                          spacing: Self.textViewVSpacing,
                          layoutMargins: .zero)
    }

    func configureSubcomponentStack(messageView: CVComponentViewMessage,
                                    stackView: ManualStackView,
                                    stackConfig: CVStackViewConfig,
                                    cellMeasurement: CVCellMeasurement,
                                    measurementKey: String,
                                    componentDelegate: CVComponentDelegate,
                                    keys: [CVComponentKey]) {

        let subviews: [UIView] = keys.compactMap { key in
            // TODO: configureSubcomponent should probably just return the componentView.
            guard let componentAndView = configureSubcomponent(messageView: messageView,
                                                               cellMeasurement: cellMeasurement,
                                                               componentDelegate: componentDelegate,
                                                               key: key) else {
                return nil
            }
            return componentAndView.componentView.rootView
        }

        stackView.reset()
        stackView.configure(config: stackConfig,
                            cellMeasurement: cellMeasurement,
                            measurementKey: measurementKey,
                            subviews: subviews)
    }

    func subcomponents(forKeys keys: [CVComponentKey]) -> [CVComponent] {
        keys.compactMap { key in
            guard let subcomponent = self.subcomponent(forKey: key) else {
                // Not all subcomponents may be present.
                return nil
            }
            return subcomponent
        }
    }

    func buildSubcomponentMap(keys: [CVComponentKey]) -> [CVComponentKey: CVComponent] {
        var result = [CVComponentKey: CVComponent]()
        for key in keys {
            guard let subcomponent = self.subcomponent(forKey: key) else {
                // Not all subcomponents may be present.
                continue
            }
            result[key] = subcomponent
        }
        return result
    }
}
