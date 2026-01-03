package 'ErYAG_Laser_System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LaserWavelength :> LengthValue {
        doc /* Wavelength of laser emission */
    }

    attribute def PulseEnergy :> EnergyValue {
        doc /* Energy delivered per laser pulse */
    }

    attribute def PulseDuration :> TimeValue {
        doc /* Temporal width of laser pulse */
    }

    attribute def RepetitionRate :> FrequencyValue {
        doc /* Pulse repetition frequency */
    }

    attribute def BeamDiameter :> LengthValue {
        doc /* Diameter of laser beam at output */
    }

    attribute def CoolingFlowRate :> VolumeFlowRateValue {
        doc /* Volumetric flow rate of coolant */
    }

    attribute def PowerSetting :> Real {
        doc /* Normalized power level 0 to 100 percent */
    }

    item def OpticalPulse {
        attribute wavelength : LaserWavelength;
        attribute energy : PulseEnergy;
        attribute duration : PulseDuration;
        attribute beamDiameter : BeamDiameter;
    }

    item def CoolantFluid {
        attribute flowRate : CoolingFlowRate;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerValue;
    }

    port def OpticalOutputPort {
        out item pulse : OpticalPulse;
    }

    port def CoolantInputPort {
        in item coolant : CoolantFluid;
    }

    port def CoolantOutputPort {
        out item coolant : CoolantFluid;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def ControlInterfacePort {
        in attribute powerCommand : PowerSetting;
        in attribute triggerSignal : Boolean;
        in attribute enableSignal : Boolean;
        out attribute systemStatus : SystemStatusKind;
        out attribute crystalTemperature : ThermodynamicTemperatureValue;
        out attribute faultCode : Integer;
    }

    enum def SystemStatusKind {
        standby;
        ready;
        lasing;
        cooling;
        fault;
        shutdown;
    }

    part def FlashLampAssembly {
        doc /* Xenon flash lamp for optical pumping of Er:YAG crystal */
        attribute peakPower : PowerValue;
        attribute flashDuration : TimeValue;
        attribute lampLifetime : Integer;
        port flashOutput : OpticalOutputPort;
        port powerIn : PowerInputPort;
        port coolingPort : CoolantInputPort;
    }

    part def ErYAGCrystalRod {
        doc /* Erbium-doped Yttrium Aluminum Garnet gain medium */
        attribute crystalLength : LengthValue;
        attribute crystalDiameter : LengthValue;
        attribute dopingConcentration : Real;
        attribute emissionWavelength : LaserWavelength = 2940[nm];
        attribute absorptionBands : LengthValue[*];
        port pumpInput : OpticalOutputPort;
        port laserOutput : OpticalOutputPort;
        port coolingPort : CoolantInputPort;
    }

    part def OpticalResonator {
        doc /* Laser cavity with high reflector and output coupler */
        attribute cavityLength : LengthValue;
        attribute outputCouplerReflectivity : Real;
        attribute qSwitchEnabled : Boolean;
        attribute qSwitchDelay : TimeValue;
        port crystalPort : OpticalOutputPort;
        port outputPort : OpticalOutputPort;
    }

    part def CoolingSubsystem {
        doc /* Closed-loop water cooling for thermal management */
        attribute targetTemperature : ThermodynamicTemperatureValue;
        attribute maxFlowRate : CoolingFlowRate;
        attribute reservoirCapacity : VolumeValue;
        port coolantIn : CoolantInputPort;
        port coolantOut : CoolantOutputPort;
        port crystalCooling : CoolantOutputPort;
        port lampCooling : CoolantOutputPort;
        port controlInterface : ControlInterfacePort;
    }

    part def HighVoltagePowerSupply {
        doc /* Capacitor discharge power supply for flash lamp */
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute capacitance : CapacitanceValue;
        attribute chargingTime : TimeValue;
        port powerIn : PowerInputPort;
        port powerOut : PowerInputPort;
        port controlInterface : ControlInterfacePort;
    }

    part def LaserControlUnit {
        doc /* Microcontroller-based control and monitoring system */
        attribute currentPowerSetting : PowerSetting;
        attribute currentTemperature : ThermodynamicTemperatureValue;
        attribute pulseCounter : Integer;
        attribute interlockStatus : Boolean;
        port controlInterface : ControlInterfacePort;
        port lampControl : ControlInterfacePort;
        port coolingControl : ControlInterfacePort;
        port safetyInterlock : ControlInterfacePort;
    }

    part def BeamDeliveryOptics {
        doc /* Beam shaping and focusing optics */
        attribute focusedSpotSize : LengthValue;
        attribute workingDistance : LengthValue;
        attribute beamDivergence : Real;
        port beamInput : OpticalOutputPort;
        port beamOutput : OpticalOutputPort;
    }

    part def SafetyInterlockSystem {
        doc /* Safety interlocks for personnel and equipment protection */
        attribute doorClosed : Boolean;
        attribute keySwitch : Boolean;
        attribute emergencyStop : Boolean;
        attribute coolingOk : Boolean;
        port interlockOut : ControlInterfacePort;
    }

    part def ErYAGLaserSystem {
        doc /* Complete Er:YAG laser system for precision material ablation and medical applications */

        part flashLamp : FlashLampAssembly {
            attribute peakPower = 8000[W];
            attribute flashDuration = 250e-6[s];
            attribute lampLifetime = 1000000;
        }

        part crystal : ErYAGCrystalRod {
            attribute crystalLength = 120[mm];
            attribute crystalDiameter = 6[mm];
            attribute dopingConcentration = 0.5;
            attribute emissionWavelength = 2940[nm];
            attribute absorptionBands = (795[nm], 970[nm], 1530[nm]);
        }

        part resonator : OpticalResonator {
            attribute cavityLength = 180[mm];
            attribute outputCouplerReflectivity = 0.7;
            attribute qSwitchEnabled = true;
            attribute qSwitchDelay = 200e-9[s];
        }

        part cooling : CoolingSubsystem {
            attribute targetTemperature = 293.15[K];
            attribute maxFlowRate = 3.0e-4[m^3/s];
            attribute reservoirCapacity = 5.0e-3[m^3];
        }

        part powerSupply : HighVoltagePowerSupply {
            attribute outputVoltage = 900[V];
            attribute maxCurrent = 60[A];
            attribute capacitance = 150e-6[F];
            attribute chargingTime = 50e-3[s];
        }

        part controller : LaserControlUnit {
            attribute currentPowerSetting = 0.0;
            attribute currentTemperature = 293.15[K];
            attribute pulseCounter = 0;
            attribute interlockStatus = false;
        }

        part beamDelivery : BeamDeliveryOptics {
            attribute focusedSpotSize = 0.3[mm];
            attribute workingDistance = 50[mm];
            attribute beamDivergence = 0.005;
        }

        part safetySystem : SafetyInterlockSystem {
            attribute doorClosed = true;
            attribute keySwitch = true;
            attribute emergencyStop = false;
            attribute coolingOk = true;
        }

        port opticalOutput : OpticalOutputPort;
        port coolingIn : CoolantInputPort;
        port coolingOut : CoolantOutputPort;
        port mainPower : PowerInputPort;
        port control : ControlInterfacePort;

        connect flashLamp.flashOutput to crystal.pumpInput;
        connect crystal.laserOutput to resonator.crystalPort;
        connect resonator.outputPort to beamDelivery.beamInput;
        connect beamDelivery.beamOutput to opticalOutput;

        connect cooling.crystalCooling to crystal.coolingPort;
        connect cooling.lampCooling to flashLamp.coolingPort;
        connect coolingIn to cooling.coolantIn;
        connect cooling.coolantOut to coolingOut;

        connect powerSupply.powerOut to flashLamp.powerIn;
        connect mainPower to powerSupply.powerIn;

        connect controller.controlInterface to control;
        connect controller.lampControl to powerSupply.controlInterface;
        connect controller.coolingControl to cooling.controlInterface;
        connect safetySystem.interlockOut to controller.safetyInterlock;

        perform action operateLaser;
    }

    action def InitializeSystem {
        in enableSignal : Boolean;
        out systemReady : Boolean;
        out interlockOk : Boolean;
    }

    action def ChargePowerSupply {
        in targetVoltage : ElectricPotentialValue;
        in chargingTime : TimeValue;
        out charged : Boolean;
        out actualVoltage : ElectricPotentialValue;
    }

    action def TriggerFlashLamp {
        in triggerSignal : Boolean;
        in voltage : ElectricPotentialValue;
        out flashComplete : Boolean;
        out pumpEnergy : EnergyValue;
    }

    action def GenerateLaserPulse {
        in pumpEnergy : EnergyValue;
        in qSwitchDelay : TimeValue;
        out laserPulse : OpticalPulse;
    }

    action def MonitorCrystalTemperature {
        out temperature : ThermodynamicTemperatureValue;
        out overheated : Boolean;
        out coolingRequired : Boolean;
    }

    action def AdjustCoolingFlow {
        in temperature : ThermodynamicTemperatureValue;
        in targetTemperature : ThermodynamicTemperatureValue;
        out flowRate : CoolingFlowRate;
    }

    action def CheckSafetyInterlocks {
        in doorClosed : Boolean;
        in keySwitch : Boolean;
        in emergencyStop : Boolean;
        in coolingOk : Boolean;
        out interlockOk : Boolean;
        out faultCode : Integer;
    }

    action def EmitPulse {
        in powerSetting : PowerSetting;
        in wavelength : LaserWavelength;
        out pulse : OpticalPulse;
    }

    action def ShutdownSystem {
        out systemOff : Boolean;
        out coolingContinue : Boolean;
    }

    action operateLaser {
        first start;

        then action initialize : InitializeSystem {
            in enableSignal = true;
            out systemReady;
            out interlockOk;
        }

        then decide;
            if initialize.systemReady and initialize.interlockOk then enterMainLoop;
            if not (initialize.systemReady and initialize.interlockOk) then performShutdown;

        action enterMainLoop;
        then merge mainLoop;

        action mainLoop {
            first action checkInterlocks : CheckSafetyInterlocks {
                in doorClosed = true;
                in keySwitch = true;
                in emergencyStop = false;
                in coolingOk = true;
                out interlockOk;
                out faultCode;
            }

            then action monitorTemp : MonitorCrystalTemperature {
                out temperature;
                out overheated;
                out coolingRequired;
            }

            then decide;
                if monitorTemp.overheated or not checkInterlocks.interlockOk then performShutdown;
                if monitorTemp.coolingRequired and checkInterlocks.interlockOk then adjustCoolingAction;
                if not monitorTemp.coolingRequired and checkInterlocks.interlockOk then waitForTrigger;

            action adjustCoolingAction : AdjustCoolingFlow {
                in temperature = monitorTemp.temperature;
                in targetTemperature = 293.15[K];
                out flowRate;
            }
            then waitForTrigger;

            action waitForTrigger {
                accept triggerSignal : Boolean;
            }

            then decide;
                if waitForTrigger.triggerSignal then fireLaser;
                if not waitForTrigger.triggerSignal then mainLoop;

            action fireLaser {
                first action chargePower : ChargePowerSupply {
                    in targetVoltage = 900[V];
                    in chargingTime = 50e-3[s];
                    out charged;
                    out actualVoltage;
                }

                then action triggerFlash : TriggerFlashLamp {
                    in triggerSignal = true;
                    in voltage = chargePower.actualVoltage;
                    out flashComplete;
                    out pumpEnergy;
                }

                then action generatePulse : GenerateLaserPulse {
                    in pumpEnergy = triggerFlash.pumpEnergy;
                    in qSwitchDelay = 200e-9[s];
                    out laserPulse;
                }

                then action emitPulse : EmitPulse {
                    in powerSetting = 85.0;
                    in wavelength = 2940[nm];
                    out pulse;
                }
            }

            then mainLoop;
        }

        action performShutdown : ShutdownSystem {
            out systemOff;
            out coolingContinue;
        }

        then done;
    }

    requirement def LaserPerformanceRequirement {
        doc /* Top-level performance requirements for Er:YAG laser system */
        require wavelengthRequirement;
        require pulseEnergyRequirement;
        require repetitionRateRequirement;
        require beamQualityRequirement;
    }

    requirement <'REQ-001'> wavelengthRequirement {
        doc /* The laser shall emit at 2940 nm wavelength with tolerance of ±10 nm */
        subject laserOutput : OpticalPulse;
        require constraint {
            laserOutput.wavelength >= 2930[nm] and laserOutput.wavelength <= 2950[nm]
        }
    }

    requirement <'REQ-002'> pulseEnergyRequirement {
        doc /* The laser pulse energy shall be adjustable from 0.1 J to 5.0 J */
        subject laserOutput : OpticalPulse;
        require constraint {
            laserOutput.energy >= 0.1[J] and laserOutput.energy <= 5.0[J]
        }
    }

    requirement <'REQ-003'> repetitionRateRequirement {
        doc /* The laser repetition rate shall not exceed 30 Hz */
        subject system : ErYAGLaserSystem;
        attribute repRate : RepetitionRate;
        require constraint {
            repRate <= 30[Hz]
        }
    }

    requirement <'REQ-004'> beamQualityRequirement {
        doc /* The focused beam diameter shall be less than 0.5 mm */
        subject delivery : BeamDeliveryOptics;
        require constraint {
            delivery.focusedSpotSize < 0.5[mm]
        }
    }

    requirement <'REQ-005'> thermalManagementRequirement {
        doc /* The crystal temperature shall be maintained between 15°C and 25°C */
        subject crystal : ErYAGCrystalRod;
        attribute operatingTemp : ThermodynamicTemperatureValue;
        require constraint {
            operatingTemp >= 288.15[K] and operatingTemp <= 298.15[K]
        }
    }

    requirement <'REQ-006'> safetyRequirement {
        doc /* The laser shall not emit unless all safety interlocks are satisfied */
        subject safetySystem : SafetyInterlockSystem;
        require constraint {
            safetySystem.doorClosed and 
            safetySystem.keySwitch and 
            not safetySystem.emergencyStop and 
            safetySystem.coolingOk
        }
    }

    requirement <'SYS-MISSION'> systemMissionRequirement : LaserPerformanceRequirement {
        doc /* The Er:YAG laser system shall deliver high-energy optical pulses at 2940 nm wavelength 
               for precision material ablation in medical and industrial applications. The system operates 
               by optically pumping an erbium-doped YAG crystal with a xenon flash lamp, generating 
               population inversion that produces stimulated emission at the characteristic 2940 nm wavelength. 
               This wavelength corresponds to strong water absorption, enabling precise tissue ablation with 
               minimal thermal damage to surrounding areas. */

        assume constraint {
            doc /* Adequate electrical power (230V AC, 15A) and cooling water supply are available */
        }

        require wavelengthRequirement;
        require pulseEnergyRequirement;
        require repetitionRateRequirement;
        require beamQualityRequirement;
        require thermalManagementRequirement;
        require safetyRequirement;
    }
}
