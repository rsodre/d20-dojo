import { SessionPolicies } from '@cartridge/presets';
import { getProfileConfig, type ProfileName } from "@/configs";

export const buildPolicies = (vrfAddress: string): SessionPolicies => {
    const profileName: ProfileName = import.meta.env.VITE_PROFILE as ProfileName;
    const profileConfig = getProfileConfig(profileName);
    
    const contracts: Record<string, any> = {};
    
    // Allowlist all systems from all contracts in the manifest
    const manifestContracts = profileConfig.manifest?.contracts || [];
    for (const contract of manifestContracts) {
        if (contract.systems && Array.isArray(contract.systems)) {
            contracts[contract.address] = {
                 methods: contract.systems.map((system: string) => ({
                     entrypoint: system
                 }))
            };
        }
    }

    // VRF contract
    contracts[vrfAddress] = {
        methods: [{ entrypoint: "request_random" }]
    };

    return { contracts };
};
