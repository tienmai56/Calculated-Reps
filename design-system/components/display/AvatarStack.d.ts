/** Overlapping avatars for session participants and "trained with" rows. */
export interface StackPerson { name: string; src?: string; }
export interface AvatarStackProps {
  people: StackPerson[];
  /** px, default 32 */
  size?: number;
  /** Show at most N, then "+n" */
  max?: number;
  /** Separator ring color — match the surface behind */
  ring?: string;
  label?: React.ReactNode;
  style?: React.CSSProperties;
}
export declare function AvatarStack(props: AvatarStackProps): JSX.Element;
