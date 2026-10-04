import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/activity_item.dart';
import '../../models/item.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ActivityQrScannerScreen
    extends StatefulWidget {
  final String activityId;
  final List<ActivityItem> activityItems;
  final Map<String, String> checkedMethods;

  const ActivityQrScannerScreen({
    super.key,
    required this.activityId,
    required this.activityItems,
    required this.checkedMethods,
  });

  @override
  State<ActivityQrScannerScreen>
      createState() =>
          _ActivityQrScannerScreenState();
}

class _ActivityQrScannerScreenState
    extends State<ActivityQrScannerScreen> {
  late final MobileScannerController
      scannerController;

  FirestoreItemRepository? itemRepository;
  FirestoreActivityRepository?
      activityRepository;

  late List<ActivityItem> activityItems;

  late Map<String, String>
      checkedMethods;

  bool isProcessing = false;

  String? message;
  bool messageIsSuccess = false;

  @override
  void initState() {
    super.initState();

    scannerController =
        MobileScannerController(
      formats: [
        BarcodeFormat.qrCode,
      ],
    );

    activityItems =
        List<ActivityItem>.from(
      widget.activityItems,
    );

    checkedMethods =
        Map<String, String>.from(
      widget.checkedMethods,
    );

    final user =
        AuthService().currentUser;

    if (user != null) {
      itemRepository =
          FirestoreItemRepository(
        userId: user.uid,
      );

      activityRepository =
          FirestoreActivityRepository(
        userId: user.uid,
      );
    }
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(
    BarcodeCapture capture,
  ) async {
    if (isProcessing) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final qrValue =
        capture.barcodes.first.rawValue;

    if (qrValue == null ||
        qrValue.trim().isEmpty) {
      return;
    }

    if (itemRepository == null ||
        activityRepository == null) {
      return;
    }

    isProcessing = true;

    try {
      final item =
          await itemRepository!
              .getItemByQrCode(
        qrValue,
      );

      if (!mounted) {
        return;
      }

      if (item == null) {
        _showTemporaryMessage(
          'QR code not recognized.',
          success: false,
        );

        return;
      }

      ActivityItem? activityItem;

      for (final existing
          in activityItems) {
        if (existing.itemId ==
            item.id) {
          activityItem = existing;
          break;
        }
      }

      if (activityItem != null) {
        if (checkedMethods
            .containsKey(
          activityItem.id,
        )) {
          _showTemporaryMessage(
            '${activityItem.itemName} is already checked.',
            success: false,
          );

          return;
        }

        setState(() {
          checkedMethods[
              activityItem!.id] = 'QR';
        });

        _showTemporaryMessage(
          '${activityItem.itemName} checked.',
          success: true,
        );

        return;
      }

      await _handleItemNotInActivity(
        item,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showTemporaryMessage(
        'Unable to process QR code.',
        success: false,
      );
    } finally {
      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      isProcessing = false;
    }
  }

  Future<void> _handleItemNotInActivity(
    Item item,
  ) async {
    await scannerController.stop();

    if (!mounted) {
      return;
    }

    final shouldAdd =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(6),
            side: const BorderSide(
              color: AppColors.ink,
              width: 2,
            ),
          ),
          title: Text(
            'Item Not in Activity',
            style:
                AppTextStyles.heading.copyWith(
              fontSize: 20,
            ),
          ),
          content: Text(
            '"${item.name}" is a known Item, '
            'but it isn\'t part of this Activity.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style:
                    AppTextStyles.bodyBold,
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.ink,
                foregroundColor:
                    AppColors.background,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Add to Activity',
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (shouldAdd == true) {
      try {
        final activityItem =
            await activityRepository!
                .addItemToActivity(
          activityId:
              widget.activityId,
          item: item,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          activityItems.add(
            activityItem,
          );

          checkedMethods[
              activityItem.id] = 'QR';
        });

        _showTemporaryMessage(
          '${item.name} added and checked.',
          success: true,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        _showTemporaryMessage(
          'Failed to add item.',
          success: false,
        );
      }
    }

    if (mounted) {
      await scannerController.start();
    }
  }

  void _showTemporaryMessage(
    String value, {
    required bool success,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      message = value;
      messageIsSuccess = success;
    });

    Future.delayed(
      const Duration(seconds: 2),
      () {
        if (!mounted ||
            message != value) {
          return;
        }

        setState(() {
          message = null;
        });
      },
    );
  }

  void _closeScanner() {
    Navigator.pop(
      context,
      checkedMethods,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller:
                    scannerController,
                onDetect:
                    _handleBarcode,
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration:
                        BoxDecoration(
                      border:
                          Border.all(
                        color:
                            Colors.white,
                        width: 3,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  GestureDetector(
                    onTap:
                        _closeScanner,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .black
                            .withValues(
                          alpha: 0.65,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          4,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .black
                          .withValues(
                        alpha: 0.65,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        4,
                      ),
                    ),
                    child: Text(
                      '${checkedMethods.length} checked',
                      style: AppTextStyles
                          .bodyBold
                          .copyWith(
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: Column(
                children: [
                  if (message != null)
                    Container(
                      width:
                          double.infinity,
                      margin:
                          const EdgeInsets
                              .only(
                        bottom: 14,
                      ),
                      padding:
                          const EdgeInsets
                              .all(12),
                      decoration:
                          BoxDecoration(
                        color:
                            messageIsSuccess
                                ? AppColors
                                    .green
                                : AppColors
                                    .ink,
                        border:
                            Border.all(
                          color:
                              Colors.white,
                          width: 1.5,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          4,
                        ),
                      ),
                      child: Text(
                        message!,
                        textAlign:
                            TextAlign.center,
                        style:
                            AppTextStyles
                                .bodyBold
                                .copyWith(
                          color:
                              Colors.white,
                        ),
                      ),
                    ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(14),
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .black
                          .withValues(
                        alpha: 0.7,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        4,
                      ),
                    ),
                    child: Text(
                      'Point the camera at an Item QR code. '
                      'The scanner stays open so you can scan multiple items.',
                      textAlign:
                          TextAlign.center,
                      style: AppTextStyles
                          .body
                          .copyWith(
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}