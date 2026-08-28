package ErYAGLaserSystem {
    public import Definitions::*;
    public import Usages::*;
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def PowerSetting;
        attribute def TriggerSignal;
        attribute def SystemPowerOn;
        attribute def FaultReset;
        attribute def ChargeCommand;
        attribute def FireCommand;
        attribute def ChargeStatus;
        attribute def TemperatureStatus;
        attribute def SafetyStatus {
            attribute doorsClosed : Boolean;
            attribute keySwitchEnabled : Boolean;
            attribute coolingOk : Boolean;
        }
        attribute def CoolantCommand;
        attribute def CoolantTemperature;
        attribute def ElectricalPulse;
        attribute def OpticalPulse;
        attribute def LaserBeam;
        attribute def ControlStatus;

        item def Coolant;
        item def LaserPulse {
            attribute wavelength : Real = 2940;
            attribute pulseEnergy : Real;
        }

        part def ErYAGCrystalRod {
            attribute wavelength : Real = 2940;
            port coolantIn { in coolant : CoolantCommand; }
            port coolantOut { out temperature : CoolantTemperature; }
            port pumpIn { in pumpPulse : OpticalPulse; }
            port laserOut { out laserPulse : OpticalPulse; }
        }

        part def XenonFlashLamp {
            port electricalIn { in discharge : ElectricalPulse; }
            port coolantIn { in coolant : CoolantCommand; }
            port coolantOut { out temperature : CoolantTemperature; }
            port lightOut { out flash : OpticalPulse; }
        }

        part def OpticalResonator {
            part crystalRod : ErYAGCrystalRod;
            part flashLamp : XenonFlashLamp;
            port beamOut { out beam : LaserBeam; }
        }

        part def HighVoltagePowerSupply {
            port chargeIn { in command : ChargeCommand; }
            port fireIn { in command : FireCommand; }
            port statusOut { out status : ChargeStatus; }
            port pulseOut { out pulse : ElectricalPulse; }
        }

        part def CoolingSubsystem {
            port commandIn { in command : CoolantCommand; }
            port coolantOut { out coolant : CoolantCommand; }
            port returnIn { in temperature : CoolantTemperature; }
            port temperatureOut { out status : TemperatureStatus; }
        }

        part def LaserControlUnit {
            port operatorIn { in power : PowerSetting; in trigger : TriggerSignal; }
            port safetyIn { in status : SafetyStatus; }
            port temperatureIn { in status : TemperatureStatus; }
            port chargeOut { out command : ChargeCommand; }
            port fireOut { out command : FireCommand; }
            port coolingOut { out command : CoolantCommand; }
            port statusOut { out status : ControlStatus; }
            exhibit state 'control states' : ControlStates;
        }

        part def SafetyInterlockSystem {
            port doorIn { in doorClosed : Boolean; }
            port keyIn { in keyEnabled : Boolean; }
            port coolingIn { in coolingOK : Boolean; }
            port statusOut { out status : SafetyStatus; }
        }

        part def BeamDeliveryOptics {
            port beamIn { in beam : LaserBeam; }
            port beamOut { out shapedBeam : LaserBeam; }
        }

        part def OperatorConsole {
            port commandOut { out power : PowerSetting; out trigger : TriggerSignal; }
            port statusIn { in status : ControlStatus; }
        }

        part def LaserSystem {
            part operatorConsole : OperatorConsole;
            part laserControlUnit : LaserControlUnit;
            part powerSupply : HighVoltagePowerSupply;
            part resonator : OpticalResonator;
            part cooling : CoolingSubsystem;
            part safety : SafetyInterlockSystem;
            part beamOptics : BeamDeliveryOptics;
            exhibit state 'laser operational state' : LaserOperationalState;
        }

        action def PerformSelfTest { out status : ControlStatus; }
        action def CheckSafetyInterlocks { out status : SafetyStatus; out ok : Boolean; }
        action def CheckTemperature { in temp : TemperatureStatus; out ok : Boolean; }
        action def ChargeCapacitors { in command : ChargeCommand; out status : ChargeStatus; }
        action def DischargeCapacitors { in command : FireCommand; in status : ChargeStatus; out pulse : ElectricalPulse; }
        action def FireFlashLamp { in pulse : ElectricalPulse; out light : OpticalPulse; }
        action def GenerateLaserPulse { in pumpLight : OpticalPulse; out beam : LaserBeam; out complete : Boolean; }
        action def ShapeBeam { in beam : LaserBeam; out shapedBeam : LaserBeam; }
        action def CirculateCoolant { in command : CoolantCommand; out temperature : CoolantTemperature; out complete : Boolean; }
        action def ProcessOperatorCommand { in power : PowerSetting; in trigger : TriggerSignal; out charge : ChargeCommand; out fire : FireCommand; }

        action def SelfTestSequence {
            in tempStatus : TemperatureStatus;
            out safetyOk : Boolean;
            out tempOk : Boolean;
            action 'perform self test': PerformSelfTest { out status; }
            action 'check safety': CheckSafetyInterlocks { out status; out ok; }
            action 'check temperature': CheckTemperature { in temp = tempStatus; out ok; }
        }

        action def FirePulseSequence {
            in chargeCmd : ChargeCommand;
            in fireCmd : FireCommand;
            out complete : Boolean;
            action 'charge capacitors': ChargeCapacitors { in command = chargeCmd; out status; }
            action 'discharge capacitors': DischargeCapacitors { in command = fireCmd; in status = 'charge capacitors'.status; out pulse; }
            action 'fire flash lamp': FireFlashLamp { in pulse = 'discharge capacitors'.pulse; out light; }
            action 'generate laser pulse': GenerateLaserPulse { in pumpLight = 'fire flash lamp'.light; out beam; out complete; }
            action 'shape beam': ShapeBeam { in beam = 'generate laser pulse'.beam; out shapedBeam; }
        }

        state def LaserOperationalState;
        state def ControlStates;

        requirement def WavelengthRequirement {
            doc /* The laser system shall emit at a wavelength of 2940 nm. */
            attribute wavelength : Real;
            require constraint { wavelength == 2940 }
        }
        requirement def WaterAbsorptionRequirement {
            doc /* The wavelength shall be highly absorbed by water for precision ablation with minimal thermal damage. */
            attribute waterAbsorptionCoefficient : Real;
            require constraint { waterAbsorptionCoefficient > 0 }
        }
        requirement def PulseEnergyRequirement {
            doc /* The laser system shall deliver high-energy pulses for material and tissue ablation. */
            attribute pulseEnergy : Real;
            attribute minPulseEnergy : Real;
            require constraint { pulseEnergy >= minPulseEnergy }
        }
        requirement def CoolingRequirement {
            doc /* The cooling subsystem shall maintain the crystal rod and flash lamp within safe temperature limits. */
            attribute crystalTemperature : Real;
            attribute flashLampTemperature : Real;
            attribute maxCrystalTemperature : Real;
            attribute maxFlashLampTemperature : Real;
            require constraint { crystalTemperature <= maxCrystalTemperature && flashLampTemperature <= maxFlashLampTemperature }
        }
        requirement def SafetyInterlockRequirement {
            doc /* The laser shall not operate unless all safety interlocks are satisfied. */
            attribute doorsClosed : Boolean;
            attribute keySwitchEnabled : Boolean;
            attribute coolingOK : Boolean;
            require constraint { doorsClosed && keySwitchEnabled && coolingOK }
        }
        requirement def BeamDeliveryRequirement {
            doc /* Beam delivery optics shall shape and focus the laser beam with high precision. */
            attribute beamDiameter : Real;
            attribute maxTargetBeamDiameter : Real;
            require constraint { beamDiameter <= maxTargetBeamDiameter }
        }
        requirement def ControlResponseRequirement {
            doc /* The laser control unit shall respond to operator commands and orchestrate the firing cycle. */
            attribute responseTime : Real;
            attribute maxResponseTime : Real;
            require constraint { responseTime <= maxResponseTime }
        }
    }

    package Usages {
        private import Definitions::*;

        action 'perform self test' : PerformSelfTest;
        action 'check safety' : CheckSafetyInterlocks;
        action 'check temperature' : CheckTemperature;
        action 'charge capacitors' : ChargeCapacitors;
        action 'discharge capacitors' : DischargeCapacitors;
        action 'fire flash lamp' : FireFlashLamp;
        action 'generate laser pulse' : GenerateLaserPulse;
        action 'shape beam' : ShapeBeam;
        action 'circulate coolant' : CirculateCoolant;
        action 'process operator command' : ProcessOperatorCommand;

        part laserSystem : LaserSystem {
            flow powerSettingFlow of PowerSetting
                from operatorConsole.commandOut.power to laserControlUnit.operatorIn.power;
            flow triggerFlow of TriggerSignal
                from operatorConsole.commandOut.trigger to laserControlUnit.operatorIn.trigger;
            flow controlStatusFlow of ControlStatus
                from laserControlUnit.statusOut.status to operatorConsole.statusIn.status;
            flow chargeFlow of ChargeCommand
                from laserControlUnit.chargeOut.command to powerSupply.chargeIn.command;
            flow fireFlow of FireCommand
                from laserControlUnit.fireOut.command to powerSupply.fireIn.command;
            flow dischargeFlow of ElectricalPulse
                from powerSupply.pulseOut.pulse to resonator.flashLamp.electricalIn.discharge;
            flow coolantFlowToCrystal of CoolantCommand
                from cooling.coolantOut.coolant to resonator.crystalRod.coolantIn.coolant;
            flow coolantFlowToLamp of CoolantCommand
                from cooling.coolantOut.coolant to resonator.flashLamp.coolantIn.coolant;
            flow crystalReturnFlow of CoolantTemperature
                from resonator.crystalRod.coolantOut.temperature to cooling.returnIn.temperature;
            flow lampReturnFlow of CoolantTemperature
                from resonator.flashLamp.coolantOut.temperature to cooling.returnIn.temperature;
            flow pumpLightFlow of OpticalPulse
                from resonator.flashLamp.lightOut.flash to resonator.crystalRod.pumpIn.pumpPulse;
            flow laserBeamFlow of LaserBeam
                from resonator.beamOut.beam to beamOptics.beamIn.beam;
            flow safetyStatusFlow of SafetyStatus
                from safety.statusOut.status to laserControlUnit.safetyIn.status;
            flow temperatureStatusFlow of TemperatureStatus
                from cooling.temperatureOut.status to laserControlUnit.temperatureIn.status;
            flow coolingCmdFlow of CoolantCommand
                from laserControlUnit.coolingOut.command to cooling.commandIn.command;
        }

        state 'laser operational state' : LaserOperationalState {
            entry; then off;
            state off;
            accept SystemPowerOn then selfTest;
            state selfTest {
                do 'self test sequence' : SelfTestSequence {
                    in tempStatus = laserSystem.cooling.temperatureOut.status;
                    out safetyOk;
                    out tempOk;
                }
            }
            accept when 'self test sequence'.safetyOk == true && 'self test sequence'.tempOk == true then ready;
            accept when 'self test sequence'.safetyOk == false || 'self test sequence'.tempOk == false then fault;
            state ready;
            accept TriggerSignal then firing;
            state firing {
                do 'fire pulse' : FirePulseSequence {
                    in chargeCmd = laserSystem.laserControlUnit.chargeOut.command;
                    in fireCmd = laserSystem.laserControlUnit.fireOut.command;
                    out complete;
                }
            }
            accept when 'fire pulse'.complete == true then cooling;
            state cooling {
                do 'circulate coolant' : CirculateCoolant {
                    in command = laserSystem.laserControlUnit.coolingOut.command;
                    out temperature;
                    out complete;
                }
            }
            accept when 'circulate coolant'.complete == true then ready;
            state fault;
            accept FaultReset then selfTest;
        }
    }
}
