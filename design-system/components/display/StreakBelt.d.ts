/**
 * Weekly friendship streak drawn as a belt of week segments (each with a tape stripe). Missed weeks are bare mat; this week is a hatched slot until you train together.
 * @startingPoint section="Display" subtitle="Belt, avatars, streak belt, badges, cards" viewport="700x420"
 */
export interface StreakBeltProps {
  /** Past weeks oldest→newest, true = trained together that week */
  weeks: boolean[];
  /** Current calendar week state */
  thisWeek?: 'done' | 'pending';
  /** Friendship hue */
  hue?: 'coral' | 'sun' | 'mint' | 'sky' | 'plum';
  size?: 'sm' | 'md';
  showFlame?: boolean;
  style?: React.CSSProperties;
}
export declare function StreakBelt(props: StreakBeltProps): JSX.Element;
