export type PlanModule = 'goalPlanner' | 'advancedAnalytics' | 'financeTracker' | 'workoutTracker' | 'learningTracker' | 'contentPlanner' | 'googleIntegrations';
export type Plan = { id: 'starter' | 'growth' | 'complete'; name: string; priceMonthly: number; priceYearly: number; popular: boolean; maxActiveHabits: number | null; maxActiveTasks: number | null; modules: Set<PlanModule>; features: string[] };
export const planCatalog: Plan[] = [
  { id: 'starter', name: 'Starter', priceMonthly: 0, priceYearly: 0, popular: false, maxActiveHabits: 3, maxActiveTasks: 20, modules: new Set(), features: ['En fazla 3 aktif habit', 'En fazla 20 aktif task', 'Temel dashboard ve haftalık plan'] },
  { id: 'growth', name: 'Growth', priceMonthly: 6, priceYearly: 60, popular: true, maxActiveHabits: null, maxActiveTasks: null, modules: new Set(['goalPlanner', 'advancedAnalytics']), features: ['Sınırsız habit ve task', 'Goal planner', 'Progress analytics', 'Aylık değerlendirme'] },
  { id: 'complete', name: 'Complete', priceMonthly: 12, priceYearly: 120, popular: false, maxActiveHabits: null, maxActiveTasks: null, modules: new Set(['goalPlanner', 'advancedAnalytics', 'financeTracker', 'workoutTracker', 'learningTracker', 'contentPlanner', 'googleIntegrations']), features: ['Growth içindeki her şey', 'Finance, Workout, Learning ve Content', 'Google entegrasyonları', 'Gelişmiş raporlar'] },
];
export const betaAllAccess = true;
export function planById(id: string) { return planCatalog.find((plan) => plan.id === id) ?? planCatalog[0]; }
export function resolvePlan(id: string | null | undefined) { return betaAllAccess ? planById('complete') : planById(id ?? 'starter'); }
export function canCreateAtLimit(limit: number | null, count: number | null) { return limit === null ? true : count !== null && count < limit; }
export function planPrice(plan: Plan, yearly = false) { const price = yearly ? plan.priceYearly : plan.priceMonthly; return price === 0 ? 'Ücretsiz' : `$${price} / ${yearly ? 'yıl' : 'ay'}`; }
