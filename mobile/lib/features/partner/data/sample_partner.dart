import '../domain/partner_dashboard.dart';

/// Fixture data behind the partner screens, taken from the Stitch designs.
///
/// **PHASE 5: delete this file.** The screens take a [PartnerDashboard] as a
/// parameter, so swapping in a repository read is a router change, not a
/// screen change.
class SamplePartner {
  const SamplePartner._();

  static const PartnerDashboard dashboard = PartnerDashboard(
    profile: PartnerProfile(
      name: 'Green Leaf Kitchen',
      category: 'Restaurant Partner',
      locality: 'Downtown',
    ),
    portionsShared: 32,
    batchCount: 3,
    activeRescues: 2,
    matchedCount: 1,
    pickupSoonCount: 1,
    pickupSoonMinutes: 12,
    pickupSoonDetail: '18 meal boxes awaiting collection.',
    rescuesComplete: 2,
    completionRate: 96,
    activeSurplus: [
      PartnerSurplus(
        id: 'meal-boxes',
        title: '25 Meal Boxes',
        status: PartnerSurplusStatus.rescuerMatched,
        imageAsset: 'assets/images/food_meal_boxes.jpg',
        windowLabel: 'Today · 7:30 PM–8:30 PM',
        detailLine: 'Vegetarian · Approx. 25 servings',
        locationLine: 'Community Hall · Rescuer arriving',
        pickupPoint: 'Pickup counter · Main entrance',
        minutesLeft: 42,
      ),
      PartnerSurplus(
        id: 'pastry-boxes',
        title: '8 Pastry Boxes',
        status: PartnerSurplusStatus.lookingForRescuer,
        imageAsset: 'assets/images/food_bakery_basket.jpg',
        windowLabel: 'Today · Until 9:15 PM',
        detailLine: 'Bakery · Approx. 8 servings',
        pickupPoint: 'Front counter · Downtown Branch',
        minutesLeft: 78,
      ),
    ],
    // The design shows a Drafts count of 1 and a History tab, but only draws
    // the Active list. These keep those tabs honest rather than empty.
    draftSurplus: [
      PartnerSurplus(
        id: 'fruit-crates',
        title: '6 Fruit Crates',
        status: PartnerSurplusStatus.draft,
        imageAsset: 'assets/images/food_fruit_box.jpg',
        windowLabel: 'Not scheduled',
        detailLine: 'Fresh produce · Approx. 18 servings',
        pickupPoint: 'Service bay · Rear entrance',
      ),
    ],
    pastSurplus: [
      PartnerSurplus(
        id: 'event-packs',
        title: '12 Meal Portions',
        status: PartnerSurplusStatus.collected,
        imageAsset: 'assets/images/food_event_packs.jpg',
        windowLabel: 'Yesterday · 6:00 PM – 7:00 PM',
        detailLine: 'Vegetarian · Approx. 12 servings',
        pickupPoint: 'Pickup counter · Main entrance',
      ),
      PartnerSurplus(
        id: 'bakery-trays',
        title: '4 Bakery Trays',
        status: PartnerSurplusStatus.expired,
        imageAsset: 'assets/images/food_bakery_basket.jpg',
        windowLabel: 'Mon · Until 8:00 PM',
        detailLine: 'Bakery · Approx. 10 servings',
        pickupPoint: 'Front counter · Downtown Branch',
      ),
    ],
    recentActivity: [
      PartnerActivityRow(
        title: '25 Meal Boxes',
        subtitle: 'Rescue completed · 10 min ago',
        badgeLabel: 'Collected ✓',
        completed: true,
      ),
      PartnerActivityRow(
        title: '12 Meal Portions',
        subtitle: 'Shared · 1 hr ago',
        badgeLabel: 'Archived',
        completed: false,
      ),
    ],
  );
}
