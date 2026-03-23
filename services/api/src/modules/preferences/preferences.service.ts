import {
  getPreferences,
  updatePreferences,
} from '../../common/mock/control-plane-data.js';

export type PreferencesPatch = Partial<{
  biometricEnabled: boolean;
  pinLockEnabled: boolean;
  autoConnectEnabled: boolean;
  killSwitchEnabled: boolean;
  notificationsEnabled: boolean;
  telemetryLevel: 'minimal' | 'elevated_lost_mode_only';
  locationPermissionStatus: 'not_requested' | 'granted_when_in_use';
  batteryOptimizationAcknowledged: boolean;
}>;

export class PreferencesService {
  getPreferences() {
    return getPreferences();
  }

  updatePreferences(patch: PreferencesPatch) {
    return updatePreferences(patch);
  }
}

export const preferencesService = new PreferencesService();
