import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/controllers/paygame_controller.dart';
import 'package:frontend/models/paygame_models.dart';
import 'package:frontend/views/user/game_detail_view.dart';

void main() {
  const coupon = CouponModel(id: 'one', name: 'ลด 20 บาท', amountSatang: 2000);
  test('Coins use the whole balance, capped after the coupon discount', () {
    final full = CheckoutDiscount(
      priceSatang: 35000,
      points: 2000,
      usePoints: true,
      coupon: coupon,
    );
    expect(full.spentPoints, 2000);
    expect(full.totalSatang, 22000);
    final capped = CheckoutDiscount(
      priceSatang: 3500,
      points: 2000,
      usePoints: true,
      coupon: coupon,
    );
    expect(capped.spentPoints, 150);
    expect(capped.totalSatang, 3500);
    expect(
      CheckoutDiscount(
        priceSatang: 3500,
        points: 9,
        usePoints: true,
      ).coinSatang,
      90,
    );
  });
  test('Coupon minimum and percentage rounding are enforced', () {
    const minimum = CouponModel(
      id: 'min',
      name: '50',
      amountSatang: 5000,
      minimumSatang: 30000,
    );
    expect(minimum.discountFor(29999), 0);
    expect(minimum.discountFor(30000), 5000);
    const percent = CouponModel(id: 'percent', name: '5%', percent: 5);
    expect(percent.discountFor(19900), 995);
    expect(coupon.discountFor(1000), 1000);
  });
  test('Redeeming creates a coupon; completion consumes it once', () {
    final controller = PaygameController();
    expect(
      controller.redeemReward(
        const RewardItem(id: 'r1', tag: '20', name: 'ลด 20', cost: 200),
      ),
      isTrue,
    );
    expect(controller.userPointsBalance, 1800);
    final id = controller.coupons.single.id;
    final order = OrderModel(
      orderId: 'order',
      gameName: 'RoV',
      packageName: '40',
      playerUid: '1234567890',
      originalPrice: 35,
      discountAmount: 35,
      totalAmount: 0,
      paymentMethod: 'QR',
      status: 'completed',
      earnedPoints: 0,
      pointsBalance: 1650,
      createdAt: DateTime(2026),
      spentPoints: 150,
      couponId: id,
    );
    controller.addOrder(order);
    expect(controller.coupons, isEmpty);
    expect(controller.pointHistory[1].amount, '−150');
    final count = controller.pointHistory.length;
    controller.addOrder(order);
    expect(controller.pointHistory.length, count);
    expect(controller.userPointsBalance, 1650);
  });
  testWidgets('Select one coupon, combine coins, and retain both on failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PaygameOrder? result;
    await tester.pumpWidget(
      MaterialApp(
        home: PaygamePayment(
          game: paygameGames['rov']!,
          pack: const PaygamePack(40, 35),
          uid: '1234567890',
          initialPoints: 2000,
          coupons: const [coupon],
          onPaymentCompleted: (order) => result = order,
        ),
      ),
    );
    await tester.tap(find.text('เลือกคูปอง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ใช้คูปองนี้'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('ยืนยันชำระเงิน ฿0'), findsOneWidget);
    await tester.tap(find.text('ยืนยันชำระเงิน ฿0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('จำลองชำระไม่สำเร็จ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    expect(result!.pointsBalance, 2000);
    expect(result!.couponId, isNull);
    expect(result!.spentPoints, 0);
    await tester.tap(find.text('ยืนยันชำระเงิน ฿0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('จำลองชำระสำเร็จ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
    expect(result!.couponId, 'one');
    expect(result!.spentPoints, 150);
    expect(result!.pointsBalance, 1850);
    expect(result!.totalSatang, 0);
    expect(tester.takeException(), isNull);
  });
}
