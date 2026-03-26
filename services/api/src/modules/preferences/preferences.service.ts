import type { LabGuardActor } from '../../common/auth/auth-types.js';
import {
  getPreferences,
  type PreferencesPatchInput,
  updatePreferences,
  verifyAppPin,
} from '../../common/control-plane/control-plane-service.js';

export type PreferencesPatch = PreferencesPatchInput;

export class PreferencesService {
  getPreferences(actor: LabGuardActor) {
    return getPreferences(actor);
  }

  updatePreferences(actor: LabGuardActor, patch: PreferencesPatch) {
    return updatePreferences(actor, patch);
  }

  verifyAppPin(actor: LabGuardActor, pin?: string) {
    return verifyAppPin(actor, pin);
  }
}

export const preferencesService = new PreferencesService();
