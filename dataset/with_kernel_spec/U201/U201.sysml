package DiathermyTherapySystem {
    import ScalarValues::*;
    
    package Types {
        attribute def Temperature :> ScalarValues::Real;
        attribute def Power :> ScalarValues::Real;
        attribute def Impedance :> ScalarValues::Real;
        attribute def TimeValue :> ScalarValues::Real;
        attribute def Frequency :> ScalarValues::Real;

        item def RFEnergy;
        item def ControlCommand;
        item def FaultSignal;
        item def CoolingMedium;

        attribute def StartSignal;
        attribute def StopSignal;
        attribute def EmergencyStopSignal;
        attribute def ResetSignal;
        attribute def SystemReadySignal;
        attribute def TreatmentCompleteSignal;
        attribute def TempThresholdExceeded;
        attribute def ImpedanceFaultSignal;
        attribute def DurationExceededSignal;

        port def RFOutputPort { out rfEnergy : RFEnergy; }
        port def RFInputPort { in rfEnergy : RFEnergy; }
        port def TempOutputPort { out temperature : Temperature; }
        port def TempInputPort { in temperature : Temperature; }
        port def ImpedanceOutputPort { out impedance : Impedance; }
        port def ImpedanceInputPort { in impedance : Impedance; }
        port def ControlOutputPort { out command : ControlCommand; }
        port def ControlInputPort { in command : ControlCommand; }
        port def FaultOutputPort { out fault : FaultSignal; }
        port def FaultInputPort { in fault : FaultSignal; }
        port def CoolingOutputPort { out medium : CoolingMedium; }
        port def CoolingInputPort { in medium : CoolingMedium; }
        port def EnableOutputPort { out enable : Boolean; }
        port def EnableInputPort { in enable : Boolean; }
        port def ShutdownOutputPort { out shutdown : Boolean; }
        port def ShutdownInputPort { in shutdown : Boolean; }
        port def UserInputPort {
            in setPower : Power;
            in setDuration : TimeValue;
            in setMode : String;
            in start : StartSignal;
            in stop : StopSignal;
            in emergencyStop : EmergencyStopSignal;
        }
        port def DisplayOutputPort {
            out temperature : Temperature;
            out impedance : Impedance;
            out power : Power;
            out status : String;
        }
    }

    package Requirements {
        private import Types::*;

        requirement def TherapeuticTemperatureReq {
            doc /* The system shall maintain tissue temperature within the therapeutic range of 40-45 degrees Celsius during active treatment. */
            attribute actualTemperature : Temperature;
            attribute minTherapeuticTemp : Temperature = 40.0;
            attribute maxTherapeuticTemp : Temperature = 45.0;
            require constraint { actualTemperature >= minTherapeuticTemp and actualTemperature <= maxTherapeuticTemp }
        }

        requirement def PowerControlReq {
            doc /* The RF generator shall deliver adjustable power output up to 200W with an accuracy of plus or minus 5 percent. */
            attribute setPower : Power;
            attribute actualPower : Power;
            attribute maxPower : Power = 200.0;
            require constraint { actualPower <= maxPower }
        }

        requirement def ImpedanceMonitoringReq {
            doc /* The system shall monitor tissue impedance and trigger a fault if impedance is below 20 Ohm or above 200 Ohm. */
            attribute measuredImpedance : Impedance;
            attribute minImpedance : Impedance = 20.0;
            attribute maxImpedance : Impedance = 200.0;
            require constraint { measuredImpedance >= minImpedance and measuredImpedance <= maxImpedance }
        }

        requirement def TreatmentDurationReq {
            doc /* The system shall automatically terminate treatment when the set duration is reached. */
            attribute elapsedTime : TimeValue;
            attribute setDuration : TimeValue;
            require constraint { elapsedTime <= setDuration }
        }

        requirement def SafetyInterlockReq {
            doc /* The safety interlock shall shut down RF output within 100 milliseconds of detecting any fault condition. */
            attribute faultResponseTime : TimeValue;
            attribute maxResponseTime : TimeValue = 0.1;
            require constraint { faultResponseTime <= maxResponseTime }
        }

        requirement def SkinCoolingReq {
            doc /* The cooling system shall maintain skin surface temperature below 38 degrees Celsius during treatment. */
            attribute skinTemperature : Temperature;
            attribute maxSkinTemp : Temperature = 38.0;
            require constraint { skinTemperature <= maxSkinTemp }
        }

        requirement def UserInterfaceReq {
            doc /* The control unit shall allow clinicians to set power, duration, and mode, and display real-time temperature and impedance. */
            attribute displayUpdateRate : TimeValue;
            attribute maxUpdateRate : TimeValue = 0.5;
            require constraint { displayUpdateRate <= maxUpdateRate }
        }
    }

    package Definitions {
        private import Types::*;

        action def GenerateRF {
            in powerLevel : Power;
            out outputPower : Power;
        }
        action def DeliverEnergy {
            in energy : Power;
        }
        action def SenseTemperature {
            out temp : Temperature;
        }
        action def SenseImpedance {
            out impedance : Impedance;
        }
        action def ProvideCooling {
            in cmd : ControlCommand;
        }
        action def ProcessUserInput {
            in power : Power;
            in duration : TimeValue;
            in mode : String;
        }
        action def MonitorTreatment {
            in temp : Temperature;
            in imp : Impedance;
            out powerCmd : ControlCommand;
            out coolingCmd : ControlCommand;
        }
        action def UpdateDisplay {
            in temp : Temperature;
            in imp : Impedance;
            in power : Power;
        }
        action def CheckSafety {
            in temp : Temperature;
            in imp : Impedance;
            in elapsed : TimeValue;
            in duration : TimeValue;
            out fault : FaultSignal;
        }
        action def ShutdownSystem;

        action def DeliverTherapy {
            action deliverEnergy : DeliverEnergy;
            action senseTemperature : SenseTemperature;
            action senseImpedance : SenseImpedance;
            action coolSkin : ProvideCooling;
        }
        action def RunTreatment {
            action monitorTreatment : MonitorTreatment;
            action updateDisplay : UpdateDisplay;
            action checkSafety : CheckSafety;
        }
        action def HandleFault {
            action shutdownSystem : ShutdownSystem;
            action updateDisplay : UpdateDisplay;
        }

        state def RFGeneratorStates;
        state def ApplicatorStates;
        state def ControlStates;
        state def SafetyStates;
        state def CoolingStates;

        part def RFGenerator {
            port powerControlPort : ControlInputPort;
            port enablePort : EnableInputPort;
            port shutdownPort : ShutdownInputPort;
            port rfOutputPort : RFOutputPort;
            port faultPort : FaultOutputPort;
            attribute currentPower : Power;
            perform action generateRF : GenerateRF;
            perform action shutdownSystem : ShutdownSystem;
            exhibit state generatorStates : RFGeneratorStates;
        }

        part def Applicator {
            port energyInputPort : RFInputPort;
            port temperaturePort : TempOutputPort;
            port impedancePort : ImpedanceOutputPort;
            port coolingPort : CoolingInputPort;
            perform action deliverTherapy : DeliverTherapy;
            exhibit state applicatorStates : ApplicatorStates;
        }

        part def TemperatureSensor {
            port sensingPort : TempOutputPort;
            perform action measureTemperature : SenseTemperature;
        }

        part def ImpedanceMonitor {
            port sensingPort : ImpedanceOutputPort;
            perform action measureImpedance : SenseImpedance;
        }

        part def ControlUnit {
            port userInputPort : UserInputPort;
            port displayPort : DisplayOutputPort;
            port controlPort : ControlOutputPort;
            port enableOutputPort : EnableOutputPort;
            port faultInputPort : FaultInputPort;
            port sensorInputPort : TempInputPort;
            port impedanceInputPort : ImpedanceInputPort;
            attribute treatmentDuration : TimeValue;
            attribute elapsedTime : TimeValue;
            attribute treatmentMode : String;
            attribute setPowerLevel : Power;
            perform action processUserInput : ProcessUserInput;
            perform action runTreatment : RunTreatment;
            perform action updateDisplay : UpdateDisplay;
            perform action handleFault : HandleFault;
            exhibit state controlStates : ControlStates;
        }

        part def SafetyInterlock {
            port tempInputPort : TempInputPort;
            port impedanceInputPort : ImpedanceInputPort;
            port rfInputPort : RFInputPort;
            port faultPort : FaultOutputPort;
            port shutdownPort : ShutdownOutputPort;
            attribute maxTemperature : Temperature = 45.0;
            attribute minImpedance : Impedance = 20.0;
            attribute maxImpedance : Impedance = 200.0;
            perform action evaluateSafety : CheckSafety;
            perform action shutdownSystem : ShutdownSystem;
            exhibit state safetyStates : SafetyStates;
        }

        part def CoolingSystem {
            port controlPort : ControlInputPort;
            port coolingOutputPort : CoolingOutputPort;
            perform action provideCooling : ProvideCooling;
            exhibit state coolingStates : CoolingStates;
        }
    }

    package Structure {
        private import Types::*;
        private import Definitions::*;
        private import Requirements::*;

        part diathermySystem {
            part rfGenerator : RFGenerator {
                exhibit state generatorStates : RFGeneratorStates {
                    entry; then idle;
                    state idle;
                    accept StartSignal then active;
                    state active { do generateRF; }
                    accept StopSignal then idle;
                    accept FaultSignal then fault;
                    state fault;
                    accept ResetSignal then idle;
                }
            }
            part applicator : Applicator {
                exhibit state applicatorStates : ApplicatorStates {
                    entry; then idle;
                    state idle;
                    accept StartSignal then delivering;
                    state delivering { do deliverTherapy; }
                    accept StopSignal then idle;
                }
            }
            part tempSensor : TemperatureSensor;
            part impedanceMonitor : ImpedanceMonitor;
            part controlUnit : ControlUnit {
                exhibit state controlStates : ControlStates {
                    entry; then idle;
                    state idle { do updateDisplay; }
                    accept StartSignal then warmup;
                    state warmup { do processUserInput; }
                    accept SystemReadySignal then active;
                    state active { do runTreatment; }
                    accept StopSignal then idle;
                    accept EmergencyStopSignal then idle;
                    accept FaultSignal then fault;
                    accept TreatmentCompleteSignal then idle;
                    state fault { do handleFault; }
                    accept ResetSignal then idle;
                }
            }
            part safetyInterlock : SafetyInterlock {
                exhibit state safetyStates : SafetyStates {
                    entry; then monitoring;
                    state monitoring { do evaluateSafety; }
                    accept FaultSignal then triggered;
                    state triggered { do shutdownSystem; }
                    accept ResetSignal then monitoring;
                }
            }
            part coolingSystem : CoolingSystem {
                exhibit state coolingStates : CoolingStates {
                    entry; then idle;
                    state idle;
                    accept StartSignal then active;
                    state active { do provideCooling; }
                    accept StopSignal then idle;
                }
            }

            connect rfGenerator.rfOutputPort to applicator.energyInputPort;
            flow rfEnergyFlow of RFEnergy
                from rfGenerator.rfOutputPort.rfEnergy to applicator.energyInputPort.rfEnergy;

            connect tempSensor.sensingPort to controlUnit.sensorInputPort;
            flow tempFlow of Temperature
                from tempSensor.sensingPort.temperature to controlUnit.sensorInputPort.temperature;

            connect tempSensor.sensingPort to safetyInterlock.tempInputPort;
            flow tempSafetyFlow of Temperature
                from tempSensor.sensingPort.temperature to safetyInterlock.tempInputPort.temperature;

            connect impedanceMonitor.sensingPort to controlUnit.impedanceInputPort;
            flow impedanceFlow of Impedance
                from impedanceMonitor.sensingPort.impedance to controlUnit.impedanceInputPort.impedance;

            connect impedanceMonitor.sensingPort to safetyInterlock.impedanceInputPort;
            flow impedanceSafetyFlow of Impedance
                from impedanceMonitor.sensingPort.impedance to safetyInterlock.impedanceInputPort.impedance;

            connect controlUnit.controlPort to rfGenerator.powerControlPort;
            flow controlCmdFlow of ControlCommand
                from controlUnit.controlPort.command to rfGenerator.powerControlPort.command;

            connect controlUnit.enableOutputPort to rfGenerator.enablePort;
            flow enableFlow of Boolean
                from controlUnit.enableOutputPort.enable to rfGenerator.enablePort.enable;

            connect controlUnit.controlPort to coolingSystem.controlPort;
            flow coolingCmdFlow of ControlCommand
                from controlUnit.controlPort.command to coolingSystem.controlPort.command;

            connect safetyInterlock.faultPort to controlUnit.faultInputPort;
            flow faultFlow of FaultSignal
                from safetyInterlock.faultPort.fault to controlUnit.faultInputPort.fault;

            connect safetyInterlock.shutdownPort to rfGenerator.shutdownPort;
            flow shutdownFlow of Boolean
                from safetyInterlock.shutdownPort.shutdown to rfGenerator.shutdownPort.shutdown;

            connect coolingSystem.coolingOutputPort to applicator.coolingPort;
            flow coolingMediumFlow of CoolingMedium
                from coolingSystem.coolingOutputPort.medium to applicator.coolingPort.medium;

            connect rfGenerator.rfOutputPort to safetyInterlock.rfInputPort;
            flow rfSafetyFlow of RFEnergy
                from rfGenerator.rfOutputPort.rfEnergy to safetyInterlock.rfInputPort.rfEnergy;

            requirement therapeuticTempRequirement : TherapeuticTemperatureReq {
                attribute :>> actualTemperature = tempSensor.sensingPort.temperature;
            }
            requirement impedanceMonitoringRequirement : ImpedanceMonitoringReq {
                attribute :>> measuredImpedance = impedanceMonitor.sensingPort.impedance;
            }
            requirement treatmentDurationRequirement : TreatmentDurationReq {
                attribute :>> elapsedTime = controlUnit.elapsedTime;
                attribute :>> setDuration = controlUnit.treatmentDuration;
            }
            requirement powerControlRequirement : PowerControlReq {
                attribute :>> setPower = controlUnit.setPowerLevel;
                attribute :>> actualPower = rfGenerator.currentPower;
            }
        }
    }

    import Types::*;
    import Definitions::*;
}
