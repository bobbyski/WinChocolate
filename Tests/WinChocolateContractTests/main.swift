import WinChocolate




// MARK: - Test-local frame-carrying init sugar
//
// The framework's frame-carrying inits are gone from the public surface
// (18.2 — AppKit has no combined content+frame inits). These compose the two
// REAL steps for the suite's many call sites.








// MARK: - Test-local closure sugar over REAL target/action + delegates
//
// The framework has no closure actions (Phase 18.2) — controls dispatch their
// real `target`/`action` selector. These helpers keep the suite's closure
// ergonomics while exercising the REAL dispatch path on every use: the
// trampoline receives the selector through `NSObject.perform(_:with:)`.






/// A real `NSTextFieldDelegate`/table/outline delegate trampoline set for
/// tests that watch text or selection changes through the delegate surface.






// Pin the suite to the light appearance: dynamic system colors resolve
// through the effective appearance, and without a pin they would follow the
// *test machine's* Windows theme, making color assertions machine-dependent.
// Tests that exercise dark behavior override this locally and restore it.
NSApplication.shared.appearance = NSAppearance(named: .aqua)

// The framework defaults to the modern presentation (8.4) — asserted here,
// then pinned to classic so the suite's classic-baseline assertions hold;
// tests that exercise modern behavior override locally and restore the pin.
expect(WinPresentation.selected == .modern, "The presentation should default to modern (8.4).")
WinPresentation.selected = .classic
















































/// A mutable flat outline (top-level leaves) for the sibling-reorder test.





/// A cell-based table delegate: it counts selection changes but vends no cell
/// view, so the table stays on the native list path (auto-detection only picks
/// the drawn peer when a delegate vends views).




















/// An outline delegate that hosts a text field per cell for the first column.


/// A small tree: "Folder" (branch → [A]) and "Loose" (leaf), for the
/// cross-level reparenting-drop test.






/// A browser tree whose root column mixes one branch and one leaf, for the
/// branch-indicator test.


/// A browser whose single leaf item carries a delegate-provided cell image.




/// A collection data source that dequeues recycled items via `makeItem`.








/// A collection data source that counts how often it is asked to vend a
/// supplementary view — for the recycling test.




































/// The frozen demo's template-tint recipe end-to-end: clicking a well presents
/// the shared panel WITHOUT firing the action; a panel pick updates the well,
/// fires the action, and the handler's `contentTintColor` re-tints a template
/// image view — the exact New-in-3.x page wiring.




















































/// A toolbar target that decides item enabling, for the validation test.


/// Records selection/lifecycle delegate callbacks for the toolbar parity test.



/// Vends fresh a/b items so a restoring toolbar can resolve identifiers.




/// Allows open + flexible space in the palette for the dimming test.















/// Records the current-drawing appearance seen inside `draw(_:)`.



































// A minimal single-value coder pair to exercise Codable conformances without
// Foundation's JSONEncoder (which WinChocolate deliberately does not depend on).
// Only the String path is implemented — the only one UUID's coding touches; the
// rest trap so an accidental use is caught rather than silently mis-tested.


/// A minimal single-value `Double` decoder for testing `Date` Codable round-trips.



// Models for the JSON coder tests.
































// The suite runs inside build scripts on a real desktop. Windows and panels
// created without an explicit backend capture the application default, which
// on Windows is the live Win32 backend — every ordered-front test window would
// flash on screen. Route the default through the in-memory backend first.
NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()

















































































testWindowRealizationCreatesNativeHierarchy()
testWindowToggleFullScreenTracksStateAndDelegate()
testAutoLayoutPinsEdgesFixedSizeAndCenter()
testAutoLayoutIntrinsicContentSize()
testStackViewDistributionsAlignmentAndInsets()
testStackViewComposesWithSolverAndResizes()
testGridViewContentSizingAndPlacement()
testGridViewHiddenStructureAndSolver()
testGridViewCellMergingSpans()
testStackViewCustomSpacingAndHiddenViews()
testAspectRatioCrossAxisConstraints()
testLayoutMarginsGuideInsetsChild()
testControlIntrinsicContentSizes()
testLayoutControlIntrinsicSizes()
testWinCoreGraphicsTransformsAndBMPCodec()
testWinCoreGraphicsPNGDecode()
testBaselineAnchorsAlignAcrossViews()
testCrossHierarchyConstraintUsesNestedFixedInput()
testStackViewGravityAreasAndEqualCentering()
testStackViewBaselineAlignment()
testGridViewStretchesAndBaselineAlignsRows()
testAutoresizingMaskMixesWithConstraintsThroughResize()
testAutoLayoutResizeReflowsConstraints()
testAutoLayoutSiblingChainInequalityAndFixedAnchor()
testWindowTitleVisibilityBlanksCaption()
testWindowStandardButtonsAndStyleFlags()
testWindowStandardButtonHidingReflectsToCaption()
testViewHierarchyMaintainsSuperviewOwnership()
testViewInsertionReplacementTagsAndDescendants()
testViewCompatibilityMetadataStoresValues()
testViewTooltipSyncsToNativePeer()
testGeometryConvenienceFunctions()
testViewCoordinateConversionAndHitTesting()
testScrollViewHostsDocumentView()
testScrollViewUsesNativePeerAndRealizesDocumentView()
testScrollViewNativeScrollbarActionUpdatesClipOrigin()
testClipViewScrollsDocumentView()
testCellStoresStringAndObjectValues()
testSortDescriptorStoresKeyDirectionAndReverse()
testTableCellAndRowViewsStoreState()
testTableColumnStoresAppKitIdentifierShape()
testTableViewReloadsRowsFromDataSource()
testTableViewColumnMovementAndRemoval()
testTableViewSelectionOptionsAndHelpers()
testTableViewDoubleClickSendsDoubleAction()
testTableViewStoresDisplayOptionsAndSetObjectValue()
testTableViewDelegateViewHeightAndSortHooks()
testTableViewTabKeyMovesThroughKeyViewLoop()
testSearchFieldTabKeyMovesThroughKeyViewLoop()
testTableViewKeyboardNavigationUpdatesSelection()
testTableViewKeyboardExtendedSelection()
testTableViewColumnSelectionAndDoubleActionSurface()
testTableViewSortDescriptorPrototypeToggle()
testOutlineViewFlattensExpandableItems()
testOutlineViewSelectionTracksItemAcrossExpandCollapse()
testOutlineViewHostsDelegateCellViews()
testOutlineViewSiblingReorderMovesItem()
testOutlineViewCrossLevelDropTargetsParent()
testBrowserLoadsColumnsAndTracksSelection()
testBrowserPathRoundTrips()
testBrowserColumnTitles()
testBrowserDrawsBranchIndicatorOnNonLeafRows()
testBrowserDrawsDelegateCellImage()
testIndexPathStoresCollectionComponents()
testCollectionViewReloadsItemsAndTracksSelection()
testCollectionViewRecyclesItemsViaMakeItem()
testCollectionViewButtonItemClickSelectsItem()
testCollectionViewFlowLayoutArrangesSectionsAndSizesContent()
testCollectionFlowLayoutHonorsPerItemSizeFromDelegate()
testCollectionFlowLayoutReservesAndHostsSectionHeaders()
testCollectionRecyclesSupplementaryViewsAcrossRelayout()
testCollectionFlowLayoutReservesSectionFooters()
testCollectionSupplementaryViewsHostInRealizedScrollView()
testCollectionFlowLayoutHorizontalVariableSizePacking()
testSliderStoresRangeValueAndSyncsNativePeer()
testSliderNativeActionUpdatesValue()
testProgressIndicatorStoresRangeValueAndSyncsNativePeer()
testSpinnerShadeInvertsForDarkAppearance()
testLevelIndicatorStoresRangeValueAndUsesProgressPeer()
testLevelIndicatorEditableClickSetsValue()
testLevelIndicatorRatingUsesCustomView()
testLevelIndicatorFillColorsAreAppearanceAware()
testDisclosureButtonTogglesAndOrientsTriangle()
testFrameworkDrawnBezelStylesUseViewPeersAndInteract()
testMinorControlCleanups()
testButtonBezelAndTextFieldBezel()
testScrollerStoresValueAndSyncsNativePeer()
testScrollerNativeActionUpdatesValue()
testScrollerHitPartReflectsGesture()
testScrollerAppearancePropagatesToNativePeer()
testDatePickerStoresDateRangeAndSyncsNativePeer()
testDatePickerClockAndCalendarStyle()
testSegmentedControlStoresSegmentsAndDrawsOnAView()
testSegmentedControlDrawsSegmentImages()
testSegmentedControlSeparatedStyleGapsSegments()
testSegmentedControlStyleDrivesCornerRadius()
testSegmentedControlPerSegmentImageAndTag()
testSegmentedControlPerSegmentMenu()
testSegmentedControlActionSelectsSegment()
testStepperStoresRangeIncrementAndSyncsNativePeer()
testStepperNativeActionUpdatesValue()
testSearchFieldTracksRecentSearchesAndNativeChanges()
testColorWellStoresColorAndSendsAction()
testColorWellPanelPickFiresActionAndTintsTemplate()
testDrawnTableScrollRowToVisibleMovesClipView()
testColorWellExpandedSwatchPalette()
testTableViewNativePeerReceivesColumnsRowsAndSelection()
testTableViewNativeSelectionNotifiesDelegateAndAction()
testTableViewActionCanReadSelectedRowValue()
testTableViewClickedRowAndColumnFollowSelection()
testSplitViewArrangesSubviewsAndDividerPosition()
testSplitViewResizeKeepsPaneProportions()
testSubviewResponderChainTargetsSuperview()
testResponderForwardsUnhandledEvents()
testWindowIsContentViewNextResponder()
testWindowMakeFirstResponderFocusesNativeView()
testWindowMakeFirstResponderHonorsResignFailure()
testApplicationTracksWindowListAndKeyMainWindow()
testWindowSelectNextAndPreviousKeyView()
testWindowSelectNextKeyViewSkipsDisabledExplicitTarget()
testWindowSelectNextKeyViewSkipsHiddenContainerChildren()
testNativeMouseDownDispatchesToView()
testNativeMouseDownOnControlMakesControlFirstResponder()
testNativeMouseUpDispatchesToView()
testNativeMouseMovedDispatchesToView()
testNativeMouseDraggedDispatchesToView()
testNativeKeyDownDispatchesToView()
testNativeKeyUpDispatchesToView()
testControlClosureActionIsInvoked()
testButtonPerformClickHonorsEnabledState()
testControlCompatibilityMetadataStoresValues()
testSwitchButtonTogglesStateOnPerformClick()
testButtonMixedStateAndCompatibilityProperties()
testRadioButtonClearsSiblingRadioButtons()
testRealizedViewStatePropagatesToBackend()
testWindowTitleAndFramePropagateToBackend()
testWindowContentSizeAndCenterUpdateFrame()
testNativeWindowResizeUpdatesContentAndAutoresizesSubviews()
testPanelStoresPanelStateAndOrdersFront()
testPopoverShowsClosesAndReopensFromAnchorView()
testPopoverFlipsWhenClipped()
testPopoverAnimatesFadesHost()
testToolbarStoresItemsAndAttachesToWindow()
testToolbarVisibilityAndItemActions()
testToolbarCustomizationDelegateAndDefaultItems()
testToolbarCustomizationAllowsDuplicateStructuralItems()
testToolbarKeepsDistinctSeparatorsWithSharedDelegateItem()
testToolbarCustomizationPaletteShowsToolbarDropTargetAtTop()
testToolbarCustomizationMovesExistingItemToEnd()
testToolbarViewComposesItemsAndDispatchesActions()
testToolbarViewHostsCustomItemView()
testToolbarItemCreatesCompositeImageLabelView()
testUserDefaultsRoundTripsPlistValues()
testToolbarItemValidationAndMenuForm()
testToolbarSelectionAndDelegateCallbacks()
testToolbarStandardItemIdentifiers()
testToolbarAutosaveRoundTripsConfiguration()
testToolbarOverflowCollapsesLowPriorityItems()
testToolbarBorderedItemRendersAsButton()
testToolbarCustomizationPaletteDimsInToolbarItems()
testToolbarCustomizationDragShowsInsertionIndicator()
testToolbarModernIdentifiersRenderAsGaps()
testToolbarRightClickPopsContextMenu()
testToolbarItemRightClickAddsRemoveItem()
testToolbarCenteredItemsLayOutCentered()
testToolbarCustomViewItemsShrinkBeforeOverflow()
testToolbarItemGroupSelectsAndFires()
testWindowToolbarActions()
testToolbarMetallicLookDrawsGradientChrome()
testToolbarAutomaticLookFollowsPresentation()
testToolbarCustomizationDragOutTintsPreviewForRemoval()
testToolbarPopupAndFieldItemsAlignVertically()
testWinPresentationSelectionAndModernSeparators()
testDrawnTableModernPresentationRestylesHeaderChrome()
testAppearanceResolvesSystemThemeAndOverrides()
testDarkAppearanceDrivesDynamicColorsAndDrawnTable()
testToolbarStripGoesDarkUnderDarkAppearance()
testCurrentDrawingAppearanceFollowsTheDrawingView()
testDataBackedNSImageDecodesAndDrawsPixels()
testSystemAccentColorDrivesAccentAndSelection()
testWrappedTextMeasurementBreaksIntoLines()
testFireDueTimersPumpsScheduledTimers()
testControlFontAppliesToButtons()
testStringEncodingIORoundTrips()
testWindowToolbarCreatesDockedComposedHostAndReservesContent()
testEditableTextFieldUsesEditableNativePeer()
testSecureTextFieldUsesSecureNativePeer()
testTextViewUsesMultilineNativePeerAndStoresText()
testTextFieldFactoryConstructorsAndCompatibilityProperties()
testTextFieldMultilineRealizesMultilineEdit()
testFormComposesTextFieldsAndStoresCells()
testMatrixComposesButtonsAndTracksSelection()
testSwitchButtonUsesCheckboxNativePeer()
testRadioButtonUsesRadioNativePeer()
testPopUpButtonUsesNativePeerAndSelection()
testPopUpButtonNativeActionUpdatesSelection()
testPopUpButtonItemLookupAndRemoval()
testComboBoxStoresItemsTextAndUsesNativePeer()
testComboBoxDataSourceSuppliesItems()
testComboBoxNativeTextChangeAndActionUpdateState()
testTokenFieldStoresTokensAndTokenizesNativeText()
testTokenFieldChipColorsAreAppearanceAware()
testPathControlStoresURLAndPathComponentCells()
testPathControlComponentURLsAndSelection()
testWinFoundationCompatibilitySurface()
testWinFoundationUUIDCodableMatchesAppleForm()
testWinFoundationJSONCoderMatchesAppleForm()
testWinFoundationRunLoopAndTimer()
testWinFoundationCoreTypeGapsClosed()
testImageViewStoresImageAndUsesNativePeer()
testTabViewStoresItemsSelectionAndUsesNativePeer()
testTabViewNativeSelectionDispatchesAction()
testNativeButtonActionMakesButtonFirstResponder()
testNativePopUpActionMakesPopUpFirstResponder()
testNativeTextChangeMakesEditableTextFieldFirstResponder()
testNativeTextChangeMakesSecureTextFieldFirstResponder()
testNativeTextChangeMakesTextViewFirstResponder()
testBoxUsesNativePeerAndSyncsTitle()
testColorValuesClampComponents()
testViewAndTextFieldColorsSyncToBackend()
testVisualEffectViewStoresMaterialAndUsesFallbackBackground()
testAppearanceSwitchNotificationReresolvesCachedBackgrounds()
testFontValuesClampSizeAndSyncToBackend()
testRemovingRealizedSubviewDestroysNativePeer()
testMainMenuQuitItemTerminatesApplication()
testMenuItemInsertionLookupAndRemoval()
testMenuItemStateAndSeparatorContracts()
testAlertReturnsFirstButtonInMemory()
testAlertRestoresKeyWindowAndFirstResponder()
testSavePanelMapsOptionsAndReturnsChosenURL()
testSavePanelCancelReturnsCancelAndClearsURL()
testOpenPanelSupportsMultipleSelectionAndDirectories()
testOpenPanelBeginInvokesCompletionHandler()
testViewDrawDispatchesPathsToBackendContext()
testViewDrawDispatchesTextAndImagesToBackendContext()
testGradientAndClipCommandsReachBackendContext()
testUndoManagerRegistersUndoAndRedo()
testTextViewUndoRestoresPreviousText()
testDocumentWindowControllersSyncTitles()
testDocumentControllerNewDocumentMakesAndShowsWindows()
testSplitViewDividerDragResizesPanes()
testCursorRectsFlowToBackendRegions()
testViewChainSeesKeyEquivalentsBeforeMenu()
testTextViewFindAndReplace()
testScrollToVisibleMovesTheClipView()
testTimerSchedulesFiresAndInvalidates()
testFileManagerCoversDocumentAppNeeds()
testDocumentWindowCloseAsksToSaveAndAutosaves()
testAttributedStringStoresStringAndAttributes()
testRightMouseScrollAndClickCountReachTheView()
testAlertCustomButtonsRunComposedModalPanel()
testRunModalReturnsScriptedStopCode()
testProgressIndicatorIndeterminateSyncsToBackend()
testMenuUpdateRunsValidationAndAutoenables()
testStringSizeUsesBackendTextMetrics()
testWindowSheetPositionsRunsModalAndEndsWithCode()
testAlertBeginSheetModalDeliversResponse()
testSavePanelSheetPassesAnchorFrame()
testOtherMouseButtonsReachTheView()
testMenuPerformKeyEquivalentMatchesControlAsCommand()
testMenuPopUpPerformsScriptedContextSelection()
testCursorSetPushPopSyncToBackend()
testTextViewSelectionInsertionAndDelegate()
testDocumentChangeCountAndOverridableDefaults()
testDocumentSavePanelFlowWritesAndReadsBack()
testDocumentControllerTracksDocumentsRecentsAndOpen()
testNSNumberBoxing()
testNumberFormatterStylesAndParsing()
testTextFieldFormatterDisplaysAndParses()
testLocaleSystemPatterns()
testTimeZoneOffsetsAndNames()
testDateFormatterPatternsAndRoundTrip()
testWindowMovableByBackgroundAndPanelKeyAndColorWell()
testDatePickerElementFormats()
testDatePickerElementFlagsMatchApple()
testDatePickerStringValueIsFullDateAndTime()
testDatePickerRendersLocalWallClock()
testDatePickerStyleRequestsAStepper()
#if !os(Windows)
testDatePickerFieldEditing()
#endif
testButtonImageAndAlternateTitle()
testTextFieldDelegateEditingCallbacks()
testPopUpButtonTagsAndPullsDown()
testAlertHelpAndIconConfiguration()
testCommonControlDepthWiresToBackend()
testSegmentedControlKeyboardSelection()
testWindowSizeLimitsAndPopoverDismiss()
testFontTraitsWeightsAndDescriptor()
testMutableAttributedStringRunsAndEnumeration()
testTextStorageAppliesRunsToTextView()
testRTFWriterEmitsTablesRunsAndEscapes()
testPasteboardAndTextViewClipboardActions()
testRichTextViewAppliesRangeFormatting()
testScrollViewWheelScrollingMovesContent()
testScrollViewMagnificationScalesGeometryAndDrawing()
testFloatingPanelStateReachesBackend()
testColorPanelFloatsAndAppliesColorsLive()
testFontPanelLiveApplyThroughFontManager()
testAlertAccessoryViewJoinsComposedPanel()


testSourceCompatSurfaceGeometryColorFontImageView()


testAlertButtonsCarryTagsKeyEquivalentsAndErrorInit()


testColorPanelHSBModeAndAlpha()


testSpinningIndicatorUsesCustomViewAndTimerSweep()



testTemplateImagesTintInDrawAndImageView()


testParagraphStyleAlignmentAndRTFRoundTrip()


testPasteboardObjectsAndFileURLs()



testTrackingAreasDeliverEnterAndExit()



testScreensAndWindowStateDepth()




testDragAndDropDestinationAndSource()



testPrintOperationRendersViewDrawing()


testTableViewMultipleSelectionEditingAndSorting()



testViewBasedTableHostsCellViews()



/// A drawn table with a single very long cell value (for the ellipsis test).


/// A delegate that dequeues its cell view via `makeView(withIdentifier:owner:)`,
/// creating a fresh one (stamped with the reuse identifier) only on a miss.


/// A drawn table whose single cell value is an attributed (colored) string.




testDrawnTableScrollsAsScrollViewDocument()
testDrawnTableClipsCellTextToColumns()
testDrawnTableTruncatesLongCellTextWithEllipsis()
testDrawnTableRendersAttributedCellValue()
testDrawnTableRecyclesCellViewsViaMakeView()
testTableColumnAutoresizing()


testDrawnTablePinnedHeaderStaysAndSorts()


testDrawnTableHeaderColumnResize()


testDrawnTableHeaderColumnReorder()

/// Vends a cell view for every cell and a custom height for the first row.


testDrawnTableHonorsVariableRowHeights()

/// Records values written back through the data source, and vends a drawn-text
/// "name" column (no view) so the drawn table paints and edits it in place.

/// Hosts a non-text view (button) in the "flag" column so the only text field
/// in the table is the in-place edit overlay.


testDrawnTableInPlaceEditCommitsToDataSource()


testDrawnTableReturnKeyBeginsEditingSelectedRow()

/// Vends a cell view (so drawn mode engages) plus a colored row view per row.


testDrawnTableHostsRowViewsWithSelectionFill()


testTableViewAutoDetectsViewBasedModeFromDelegate()


/// A table that accepts an external text drop as a new row at the drop index.


/// A read-only table whose rows drag out as their text (a pasteboard writer).





testTableHeaderViewTracksClickedColumnAndGeometry()
testDrawnTableRowReorderDragMovesRow()
testDrawnTableMultiRowReorderMovesSelection()
testDrawnTableRowDragsOutViaPasteboardWriter()
testDrawnTableAcceptsExternalRowDrop()



testNeedsLayoutArmsCoalescedPumpFlush()

// MARK: - Phase 10.2 Accessibility





// MARK: - Phase 10.6 Cursor/hover polish


// MARK: - Phase 10.1 Focus / key loop


// MARK: - Phase 10.8 Search-field chrome


// MARK: - Phase 10.9 Window-modal sheets


// MARK: - Phase 10.11 drag image + 10.7 display scale



testUnchangedFrameDoesNotRepushToBackend()
// MARK: - Phase 15 NIB / XIB loading





testNibInstantiatesXibObjectGraph()
testNibDecodesConstraintsThroughTheSolverTypes()
testNibLoadsWindowsControllersAndTheDemoPanelFromDisk()
testPlainAlertComposesADarkPanelInsteadOfTheLightMessageBox()

testControlsExposeAppKitAccessibilityRolesAndValues()
testAccessibilityTreeWalksContainerHierarchy()
testDrawnTablePublishesRowAndCellAccessibilityTree()
testAccessibilityLabelPropagatesToNativePeer()
testTextFieldShowsIBeamAndHeaderShowsResizeCursor()
testDrawnTableTabAdvancesCellEditor()
testSearchFieldDrawsChromeAndRecentMenu()
testSheetsLinkParentPositionBelowToolbarAndQueue()
testDragImageAndDisplayScaleSurfaces()

// MARK: - Phase 18.1: real target/action selector dispatch

/// An action target using the Apple-shaped dispatch surface: it advertises a
/// selector through `responds(to:)` and receives it through `perform(_:with:)`
/// — a plain Swift override, the supported way application code receives
/// selector actions on Windows (macOS builds use `@objc` methods instead).

/// A responder handling a custom selector, for nil-target chain walks.


testTargetActionDispatchesThroughRealSelectors()

// MARK: - Phase 18.7/18.8: AppKit's drag-reorder recipe

/// A minimal dragging info for driving reorder drops in tests.

/// A table source following AppKit's reorder recipe (writer + acceptDrop).

/// An outline source following AppKit's reorder recipe.


testAppKitReorderRecipeEnablesAndAcceptsDrops()

// A NumberFormatter subclass — this only compiles because WinFoundation's is
// `open`, as Foundation's is. Subclassing a formatter to adjust one method is
// ordinary AppKit practice, so it must not need a source change on Windows.


testPanelIsRealizedAsAnOwnedWindow()


testControlClassHierarchyMatchesAppKit()


testFoundationTypesMatchApplesShapes()

testWindowFrameAutosaveRoundTrips()

// Docs/NSDOCUMENT_PLAN.md Phase 1 — the Foundation pieces documents stand on.
testFileWrapperRoundTripsARegularFile()
testFileWrapperRoundTripsADirectoryTree()
testFileWrapperNamesChildrenWithoutCollisions()
testFileWrapperSerializationRoundTrips()
testDocumentReadFailuresReportCocoaErrors()

// Docs/NSDOCUMENT_PLAN.md Phase 2 — a nil-target saveDocument: must reach the
// front document, which is how every document app's File menu is wired.
testNilTargetSaveReachesTheDocumentThroughTheChain()
testNilTargetDocumentActionsReachTheDocumentController()
testMenuValidationAsksTheChainForNilTargetItems()

// Docs/NSDOCUMENT_PLAN.md Phases 3-5 — the document surface itself.
testChangeCountUndoingBackToCleanLeavesDocumentUnedited()
testChangeCountTokenKeepsEditsMadeDuringASave()
testDocumentEnumRawValuesMatchApple()
testDocumentUndoManagerDefaultsMatchApple()
testDocumentReadWriteLadderUsesFileWrapperRung()
testWriteSafelyKeepsThePreviousFileWhenWritingFails()
testUntitledDocumentsAreNumberedLikeAppKit()
testOpeningAnAlreadyOpenFileBringsItForwardInsteadOfDuplicating()
testDocumentValidationDisablesActionsThatCannotWork()
testWindowControllerLoadsItsWindowLazilyLikeAppKit()

testQuitReviewsUnsavedDocumentsBeforeAskingTheDelegate()
testTerminateReplyRawValuesMatchApple()

// Docs/NSDOCUMENT_PLAN.md Phase 6 — the same API over five backends.
testDocumentsRoundTripThroughASubstituteFilesystem()
testWindowDocumentChromeReachesTheBackend()

print("WinChocolate contract tests passed.")
