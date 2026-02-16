package 'ErGlassLaserSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WavelengthValue :> LengthValue;
    attribute def PulseDurationValue :> TimeValue;
    attribute def RepetitionRateValue :> FrequencyValue;
    attribute def BeamQualityValue :> Real;
    attribute def InversionDensityValue :> Real;

    item def OpticalPulse {
        attribute wavelength : WavelengthValue;
        attribute energy : EnergyValue;
        attribute duration : PulseDurationValue;
        attribute peakPower : PowerValue;
    }

    item def PumpEnergy {
        attribute power : PowerValue;
        attribute wavelength : WavelengthValue;
        attribute duration : PulseDurationValue;
    }

    item def CoolantFlow {
        attribute flowRate : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    port def OpticalOutputPort {
        out item pulse : OpticalPulse;
    }

    port def PumpInputPort {
        in item pumpLight : PumpEnergy;
    }

    port def CoolingPort {
        in item coolant : CoolantFlow;
    }

    port def ElectricalPort {
        in attribute voltage : Real;
        in attribute current : ElectricCurrentValue;
    }

    port def TriggerPort {
        in attribute triggerSignal : Boolean;
        out attribute readyStatus : Boolean;
    }

    part def ErGlassGainMedium {
        doc /* Erbium-doped phosphate glass rod serving as the active laser medium */
        attribute erbiumConcentration : Real;
        attribute rodLength : LengthValue;
        attribute rodDiameter : LengthValue;
        attribute storedEnergy : EnergyValue;
        attribute inversionDensity : InversionDensityValue;
        attribute emissionWavelength : WavelengthValue = 1.54e-6 [m];

        port pumpIn : PumpInputPort;
        port coolantIn : CoolingPort;
    }

    part def FlashlampPumpAssembly {
        doc /* Xenon flashlamp providing optical pumping energy */
        attribute peakPower : PowerValue;
        attribute pulseEnergy : EnergyValue;
        attribute flashDuration : PulseDurationValue;
        attribute pumpWavelength : WavelengthValue = 0.8e-6 [m];

        port electricalIn : ElectricalPort;
        port pumpOut : PumpInputPort;
    }

    part def OpticalResonator {
        doc /* Laser cavity with high reflector and output coupler mirrors */
        attribute cavityLength : LengthValue;
        attribute roundTripTime : TimeValue;

        part highReflectorMirror {
            attribute reflectivity : Real = 0.995;
        }

        part outputCouplerMirror {
            attribute reflectivity : Real = 0.65;
            attribute transmission : Real = 0.35;
        }
    }

    part def QSwitchModule {
        doc /* Electro-optic or acousto-optic Q-switch for pulse generation */
        attribute switchingSpeed : TimeValue;
        attribute holdoffTime : TimeValue;
        attribute insertionLoss : Real;

        port controlIn : TriggerPort;
    }

    part def ThermalManagementSystem {
        doc /* Active cooling system for heat dissipation */
        attribute coolingCapacity : PowerValue;
        attribute operatingTemperature : ThermodynamicTemperatureValue;
        attribute maxTemperature : ThermodynamicTemperatureValue = 350.0 [K];

        port coolantOut : CoolingPort;
        port powerIn : ElectricalPort;
    }

    part def CapacitorBankPowerSupply {
        doc /* High-voltage capacitor bank for flashlamp discharge */
        attribute capacitance : Real;
        attribute chargeVoltage : Real;
        attribute storedEnergy : EnergyValue;
        attribute chargingTime : TimeValue;

        port powerOut : ElectricalPort;
    }

    part def BeamShapingOptics {
        doc /* Collimation and beam quality enhancement optics */
        attribute focalLength : LengthValue;
        attribute beamQuality : BeamQualityValue;
        attribute transmissionEfficiency : Real;

        port opticalIn : OpticalOutputPort;
        port opticalOut : OpticalOutputPort;
    }

    state def LaserOperationStateMachine {
        entry; then standby;

        state standby {
            doc /* System idle, ready to accept trigger */
        }

        state charging {
            doc /* Capacitor bank charging to operating voltage */
        }

        state pumping {
            doc /* Flashlamp fires, Er:glass absorbs pump energy */
        }

        state inversionBuildup {
            doc /* Population inversion accumulates in gain medium */
        }

        state qSwitchClosed {
            doc /* Q-switch blocks cavity, energy storage phase */
        }

        state qSwitchOpening {
            doc /* Q-switch transitions to low-loss state */
        }

        state giantPulseEmission {
            doc /* High-power laser pulse generated and emitted */
        }

        state thermalRecovery {
            doc /* Cooling period before next pulse */
        }

        transition standby_to_charging
            first standby
            accept at TriggerPort::triggerSignal
            then charging;

        transition charging_to_pumping
            first charging
            then pumping;

        transition pumping_to_inversion
            first pumping
            then inversionBuildup;

        transition inversion_to_qClosed
            first inversionBuildup
            then qSwitchClosed;

        transition qClosed_to_qOpening
            first qSwitchClosed
            then qSwitchOpening;

        transition qOpening_to_emission
            first qSwitchOpening
            then giantPulseEmission;

        transition emission_to_recovery
            first giantPulseEmission
            then thermalRecovery;

        transition recovery_to_standby
            first thermalRecovery
            then standby;
    }

    action def AbsorbPumpEnergy {
        in pumpPower : PowerValue;
        in pumpDuration : PulseDurationValue;
        in absorptionEfficiency : Real;
        out absorbedEnergy : EnergyValue;
        out excitedStatePopulation : Real;
    }

    action def AccumulateInversion {
        in excitedPopulation : Real;
        in groundPopulation : Real;
        in relaxationTime : TimeValue;
        out inversionDensity : InversionDensityValue;
        out storedEnergy : EnergyValue;
    }

    action def ReleaseGiantPulse {
        in storedEnergy : EnergyValue;
        in cavityQFactor : Real;
        in outputCoupling : Real;
        out pulseEnergy : EnergyValue;
        out pulseDuration : PulseDurationValue;
        out peakPower : PowerValue;
    }

    action def ManageThermalLoad {
        in heatGenerated : PowerValue;
        in coolantFlowRate : VolumeValue;
        in ambientTemperature : ThermodynamicTemperatureValue;
        out rodTemperature : ThermodynamicTemperatureValue;
        out coolingEfficiency : Real;
    }

    action def GenerateHighEnergyPulse {
        doc /* Primary laser operation cycle producing Q-switched output pulse */

        first start;

        then action chargeCapacitors {
            out capacitorVoltage : Real;
            out storedCapacitorEnergy : EnergyValue;
        }

        then action triggerFlashlamp {
            in voltage = chargeCapacitors.capacitorVoltage;
            out pumpPulse : PumpEnergy;
        }

        then action pumpGainMedium : AbsorbPumpEnergy {
            in pumpPower = triggerFlashlamp.pumpPulse.power;
            in pumpDuration = triggerFlashlamp.pumpPulse.duration;
            in absorptionEfficiency = 0.75;
            out absorbedEnergy;
            out excitedStatePopulation;
        }

        then action buildInversion : AccumulateInversion {
            in excitedPopulation = pumpGainMedium.excitedStatePopulation;
            in groundPopulation = 1.0;
            in relaxationTime = 0.0001 [s];
            out inversionDensity;
            out storedEnergy;
        }

        then action closeQSwitch {
            in inversionLevel = buildInversion.inversionDensity;
            out cavityQuality : Real;
        }

        then action openQSwitch {
            in maxInversion = buildInversion.storedEnergy;
            out switchedQuality : Real;
        }

        then action emitPulse : ReleaseGiantPulse {
            in storedEnergy = buildInversion.storedEnergy;
            in cavityQFactor = openQSwitch.switchedQuality;
            in outputCoupling = 0.35;
            out pulseEnergy;
            out pulseDuration;
            out peakPower;
        }

        then action coolRod : ManageThermalLoad {
            in heatGenerated = emitPulse.pulseEnergy / emitPulse.pulseDuration;
            in coolantFlowRate = 0.001 [m^3];
            in ambientTemperature = 293.15 [K];
            out rodTemperature;
            out coolingEfficiency;
        }

        then done;
    }

    part def ErGlassLaserSystem {
        doc /* 
            Complete Er:glass laser system for high-energy pulsed operation.
            Primary function: Generate high-energy optical pulses at 1.54 micron 
            wavelength through Q-switched operation for applications including 
            rangefinding, LIDAR, and materials processing.
        */

        attribute nominalWavelength : WavelengthValue = 1.54e-6 [m];
        attribute nominalPulseEnergy : EnergyValue = 2.0 [J];
        attribute repetitionRate : RepetitionRateValue = 10.0 [Hz];
        attribute beamQuality : BeamQualityValue = 1.8;

        part gainRod : ErGlassGainMedium {
            attribute erbiumConcentration = 3.0;
            attribute rodLength = 150.0e-3 [m];
            attribute rodDiameter = 6.35e-3 [m];
        }

        part flashlamp : FlashlampPumpAssembly {
            attribute peakPower = 100000.0 [W];
            attribute pulseEnergy = 600.0 [J];
            attribute flashDuration = 0.0006 [s];
        }

        part resonator : OpticalResonator {
            attribute cavityLength = 0.4 [m];
            attribute roundTripTime = 2.67e-9 [s];
        }

        part qSwitch : QSwitchModule {
            attribute switchingSpeed = 20.0e-9 [s];
            attribute holdoffTime = 0.0003 [s];
            attribute insertionLoss = 0.05;
        }

        part cooling : ThermalManagementSystem {
            attribute coolingCapacity = 1500.0 [W];
            attribute operatingTemperature = 298.15 [K];
        }

        part powerSupply : CapacitorBankPowerSupply {
            attribute capacitance = 200.0e-6;
            attribute chargeVoltage = 2500.0;
            attribute storedEnergy = 625.0 [J];
            attribute chargingTime = 0.08 [s];
        }

        part outputOptics : BeamShapingOptics {
            attribute focalLength = 0.15 [m];
            attribute beamQuality = 1.8;
            attribute transmissionEfficiency = 0.95;
        }

        port laserOutput : OpticalOutputPort;
        port mainPower : ElectricalPort;
        port systemTrigger : TriggerPort;

        connect powerSupply.powerOut to flashlamp.electricalIn;
        connect flashlamp.pumpOut to gainRod.pumpIn;
        connect cooling.coolantOut to gainRod.coolantIn;
        connect cooling.powerIn to mainPower;
        connect qSwitch.controlIn to systemTrigger;

        perform action operateLaser : GenerateHighEnergyPulse;

        state operatingState : LaserOperationStateMachine;
    }

    part erGlassLaserSystem : ErGlassLaserSystem;

    requirement def LaserPerformanceRequirement {
        doc /* Core performance specifications for Er:glass laser system */

        subject systemInstance : ErGlassLaserSystem;

        require constraint wavelengthSpecification {
            doc /* Output wavelength shall be 1540 nm ± 20 nm for eye-safe operation */
            systemInstance.nominalWavelength >= 1.52e-6 [m] and
            systemInstance.nominalWavelength <= 1.56e-6 [m]
        }

        require constraint pulseEnergySpecification {
            doc /* Pulse energy shall exceed 1.5 J per pulse */
            systemInstance.nominalPulseEnergy >= 1.5 [J]
        }

        require constraint pulseDurationSpecification {
            doc /* Pulse duration shall be less than 100 ns FWHM */
            true
        }

        require constraint beamQualitySpecification {
            doc /* Beam quality M² shall be less than 2.5 */
            systemInstance.beamQuality <= 2.5
        }

        require constraint repetitionRateSpecification {
            doc /* System shall support repetition rates up to 10 Hz */
            systemInstance.repetitionRate <= 10.0 [Hz]
        }

        require constraint thermalStabilitySpecification {
            doc /* Gain medium temperature shall remain below 350 K during continuous operation */
            systemInstance.cooling.operatingTemperature <= systemInstance.cooling.maxTemperature
        }
    }

    requirement <'ER-LASER-SYS-001'> systemRequirement : LaserPerformanceRequirement {
        doc /* 
            The Er:glass laser system shall generate high-energy, Q-switched optical 
            pulses at 1.54 micron wavelength for rangefinding and remote sensing applications.
            The system operates by optically pumping an erbium-doped glass rod with a xenon 
            flashlamp, building population inversion, and releasing stored energy as a giant 
            pulse when the Q-switch opens the optical resonator cavity.
        */

        subject systemInstance = erGlassLaserSystem;

        assume constraint pumpEnergyAssumption {
            doc /* Flashlamp provides sufficient pump energy for population inversion */
            erGlassLaserSystem.flashlamp.pulseEnergy >= 500.0 [J]
        }

        assume constraint coolingCapacityAssumption {
            doc /* Cooling system maintains thermal equilibrium at rated repetition rate */
            erGlassLaserSystem.cooling.coolingCapacity >= 1200.0 [W]
        }
    }
}
