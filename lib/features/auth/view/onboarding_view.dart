import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cp_button.dart';
import '../../../core/widgets/motion.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../viewmodel/onboarding_viewmodel.dart';

/// Pantalla 2 — las tres láminas de bienvenida.
///
/// `RF-AUT-02`: se muestran una sola vez por instalación y «Saltar» está
/// siempre disponible, en las tres.
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingViewModelProvider).complete();
    if (mounted) context.go(Routes.welcome);
  }

  void _next(OnboardingViewModel viewModel) {
    if (viewModel.isLastSlide) {
      _finish();
      return;
    }
    _pageController.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final viewModel = ref.watch(onboardingViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: TextButton(onPressed: _finish, child: Text(l10n.commonSkip)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: viewModel.slideCount,
                onPageChanged: viewModel.goTo,
                itemBuilder: (context, index) => _Slide(slide: OnboardingSlide.values[index]),
              ),
            ),
            _Dots(count: viewModel.slideCount, current: viewModel.index),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: CpButton(
                label: viewModel.isLastSlide ? l10n.onboardingStart : l10n.commonNext,
                onPressed: () => _next(viewModel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    final (icon, title, body) = switch (slide) {
      OnboardingSlide.batchRegistration => (
        Icons.grid_view_rounded,
        l10n.onboardingBatchTitle,
        l10n.onboardingBatchBody,
      ),
      OnboardingSlide.genealogy => (
        Icons.account_tree_outlined,
        l10n.onboardingGenealogyTitle,
        l10n.onboardingGenealogyBody,
      ),
      OnboardingSlide.backup => (
        Icons.cloud_done_outlined,
        l10n.onboardingBackupTitle,
        l10n.onboardingBackupBody,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CpFloat(
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 72, color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            height: 8,
            width: index == current ? 24 : 8,
            decoration: BoxDecoration(
              color: index == current ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}
