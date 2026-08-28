package ErbiumGlassLaserSystem {
    private import SI::s;
    private import SI::m;
    private import SI::W;
    private import SI::J;
    private import SI::K;
    private import ScalarValues::*;
    private import ISQ::*;

    item def TriggerSignal;
    item def ChargeComplete;
    item def PumpComplete;
    item def PulseEmitted;
    item def RecoveryComplete;
    item def QSwitchCommand;

    item def LightPulse {
        attribute wavelength : Real = 1.54e-6;
        attribute energy : Real;
        attribute duration : Real;
    }

    item def ElectricalEnergy {
        attribute amount : Real;
    }

    item def CoolantFlow {
        attribute temperature : Real;
        attribute flowRate : Real;
    }

    port def LightPulsePort {
        in/out light : LightPulse;
    }

    port def ElectricalEnergyPort {
        in/out energy : ElectricalEnergy;
    }

    port def CoolantFlowPort {
        in/out coolant : CoolantFlow;
    }

    port def TriggerPort {
        in trigger : TriggerSignal;
    }

    port def QSwitchControlPort {
        in command : QSwitchCommand;
    }

    part def ErbiumDopedGlassRod {
        attribute length : Real = 0.1;
        attribute diameter : Real = 0.01;
        in port pumpLightPort : LightPulsePort;
        in port coolantPort : CoolantFlowPort;
        out port laserEmissionPort : LightPulsePort;
    }

    part def XenonFlashlampAssembly {
        in port powerPort : ElectricalEnergyPort;
        in port coolantPort : CoolantFlowPort;
        out port flashPort : LightPulsePort;
    }

    part def CapacitorBankPowerSupply {
        attribute storedEnergy : Real := 0;
        in port chargePort : TriggerPort;
        out port dischargePort : ElectricalEnergyPort;
    }

    part def QSwitchModule {
        attribute isOpen : Boolean := false;
        in port controlPort : QSwitchControlPort;
    }

    part def OpticalResonator {
        part highReflector;
        part outputCoupler;
        part gainMedium : ErbiumDopedGlassRod;
        part qSwitch : QSwitchModule;
        out port resonatorOutput : LightPulsePort;
    }

    part def BeamShapingOptics {
        in port inputPort : LightPulsePort;
        out port outputPort : LightPulsePort;
    }

    part def ThermalManagementSystem {
        out port coolantOut : CoolantFlowPort;
        action circulateCoolant;
    }

    part def LaserSystem {
        in port triggerPort : TriggerPort;
        out port laserOutputPort : LightPulsePort;

        part capacitorBank : CapacitorBankPowerSupply;
        part flashlamp : XenonFlashlampAssembly;
        part resonator : OpticalResonator;
        part beamShaping : BeamShapingOptics;
        part thermalMgmt : ThermalManagementSystem;

        flow powerFlow of ElectricalEnergy
            from capacitorBank.dischargePort.energy to flashlamp.powerPort.energy;
        flow pumpLightFlow of LightPulse
            from flashlamp.flashPort.light to resonator.gainMedium.pumpLightPort.light;
        flow resonatorLightFlow of LightPulse
            from resonator.resonatorOutput.light to beamShaping.inputPort.light;
        flow outputLightFlow of LightPulse
            from beamShaping.outputPort.light to laserOutputPort.light;

        flow coolantToRod of CoolantFlow
            from thermalMgmt.coolantOut.coolant to resonator.gainMedium.coolantPort.coolant;
        flow coolantToFlashlamp of CoolantFlow
            from thermalMgmt.coolantOut.coolant to flashlamp.coolantPort.coolant;

        state laserOperation {
            entry;
            then standby;

            state standby;
            transition standby_to_charging
                first standby
                accept TriggerSignal
                then charging;

            state charging {
                do assign capacitorBank.storedEnergy := 500;
            }
            transition charging_to_pumping
                first charging
                accept ChargeComplete
                then pumping;

            state pumping {
                do {
                    assign capacitorBank.storedEnergy := 0;
                    assign resonator.qSwitch.isOpen := false;
                }
            }
            transition pumping_to_emitting
                first pumping
                accept PumpComplete
                then emitting;

            state emitting {
                do assign resonator.qSwitch.isOpen := true;
            }
            transition emitting_to_recovery
                first emitting
                accept PulseEmitted
                then recovery;

            state recovery {
                do thermalMgmt.circulateCoolant;
            }
            transition recovery_to_standby
                first recovery
                accept RecoveryComplete
                then standby;
        }
    }

    part laserSystem : LaserSystem;

    requirement EyeSafeWavelength {
        doc /* The laser must emit at an eye-safe wavelength of 1.54 microns. */
        attribute wavelength : Real = 1.54e-6;
    }

    requirement HighPulseEnergy {
        doc /* The laser pulse energy must exceed 100 mJ. */
        attribute minEnergy : Real = 0.1;
    }

    requirement ShortPulseDuration {
        doc /* The pulse duration must be less than 10 nanoseconds. */
        attribute maxDuration : Real = 10.0e-9;
    }

    requirement ThermalStability {
        doc /* The system must maintain operating temperature below 40 degrees Celsius. */
        attribute maxTemp : Real = 313.15;
    }

    satisfy EyeSafeWavelength by laserSystem.laserOutputPort;
    satisfy HighPulseEnergy by laserSystem.laserOutputPort;
    satisfy ShortPulseDuration by laserSystem.laserOutputPort;
    satisfy ThermalStability by laserSystem.thermalMgmt;
}
