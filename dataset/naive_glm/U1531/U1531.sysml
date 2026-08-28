package WaveSolderingSystem {

    import ScalarValues::*;

    // =====================================================
    // VALUE TYPES WITH UNITS
    // =====================================================

    value type TemperatureC :> Real {
        doc /* Temperature in degrees Celsius */;
    }

    value type ConveySpeedMmPerSec :> Real {
        doc /* Conveyor speed in millimeters per second */;
    }

    value type FluxDensityGPerCm3 :> Real {
        doc /* Flux density in grams per cubic centimeter */;
    }

    value type WaveHeightMm :> Real {
        doc /* Solder wave height in millimeters */;
    }

    value type FlowRateMlPerSec :> Real {
        doc /* Flow rate in milliliters per second */;
    }

    value type PowerW :> Real {
        doc /* Power in watts */;
    }

    value type AirFlowM3PerMin :> Real {
        doc /* Air flow rate in cubic meters per minute */;
    }

    value type LengthMm :> Real {
        doc /* Length in millimeters */;
    }

    value type Percentage :> Real {
        doc /* Percentage value from 0 to 100 */;
    }

    value type RotationsPerMin :> Real {
        doc /* Rotations per minute */;
    }

    // =====================================================
    // ENUMERATIONS
    // =====================================================

    enum def InspectionResult {
        ACCEPTED;
        REJECTED;
        REWORK;
    }

    enum def SystemState {
        IDLE;
        PREHEATING;
        OPERATIONAL;
        SHUTDOWN;
        FAULTED;
    }

    enum def FaultType {
        NONE;
        OVERHEAT;
        MOTOR_FAULT;
        LOW_FLUX;
        LOW_SOLDER;
        CAMERA_ERROR;
        SENSOR_FAILURE;
    }

    // =====================================================
    // ITEM DEFINITIONS
    // =====================================================

    item def PrintedCircuitBoard {
        attribute boardId : String;
        attribute length : LengthMm = 200.0;
        attribute width : LengthMm = 150.0;
        attribute thicknessMm : Real = 1.6;
        attribute currentTemp : TemperatureC = 25.0;
        attribute isFluxed : Boolean = false;
        attribute isPreheated : Boolean = false;
        attribute isSoldered : Boolean = false;
        attribute isCooled : Boolean = false;
        attribute isInspected : Boolean = false;
        attribute isAccepted : Boolean = false;
        attribute defectCount : Integer = 0;
    }

    item def LiquidFlux {
        attribute density : FluxDensityGPerCm3 = 0.85;
        attribute volumeRemainingMl : Real = 500.0;
        attribute isActive : Boolean = true;
        attribute brand : String;
    }

    item def MoltenSolder {
        attribute alloyType : String = "Sn63Pb37";
        attribute temperature : TemperatureC = 25.0;
        attribute volumeL : Real = 45.0;
        attribute isMolten : Boolean = false;
    }

    // =====================================================
    // PORT DEFINITIONS
    // =====================================================

    port def BoardPort {
        inout item board : PrintedCircuitBoard;
    }

    port def FluxSupplyPort {
        out item flux : LiquidFlux;
    }

    port def SolderSupplyPort {
        out item solder : MoltenSolder;
    }

    port def ControlPort {
        in attribute enable : Boolean;
        in attribute targetValue : Real;
        out attribute actualValue : Real;
        out attribute faultFlag : Boolean;
    }

    port def InspectionResultPort {
        out attribute result : InspectionResult;
    }

    // =====================================================
    // SUB-COMPONENT PART DEFINITIONS
    // =====================================================

    part def SprayNozzle {
        attribute flowRate : FlowRateMlPerSec = 2.5;
        attribute isSpraying : Boolean = false;
        attribute sprayAngleDeg : Real = 45.0;
        attribute nozzleDiameterMm : Real = 0.5;

        action def Spray {
            in durationSec : Real;
        }
    }

    part def HeatingElement {
        attribute maxPower : PowerW = 2000.0;
        attribute currentPower : PowerW = 0.0;
        attribute isOn : Boolean = false;
        attribute efficiencyPct : Percentage = 92.0;

        action def Activate {
            in power : PowerW;
        }
        action def Deactivate {
        }
    }

    part def ConveyorMotor {
        attribute speed : ConveySpeedMmPerSec = 10.0;
        attribute isRunning : Boolean = false;
        attribute direction : String = "forward";
        attribute maxSpeed : ConveySpeedMmPerSec = 50.0;

        action def Start {
            in targetSpeed : ConveySpeedMmPerSec;
        }
        action def Stop {
        }
    }

    part def WavePump {
        attribute pumpSpeed : RotationsPerMin = 1500.0;
        attribute isPumping : Boolean = false;
        attribute waveHeightSetting : WaveHeightMm = 8.0;
        attribute maxPumpSpeed : RotationsPerMin = 3000.0;

        action def StartPumping {
            in targetSpeed : RotationsPerMin;
        }
        action def StopPumping {
        }
    }

    part def SolderPot {
        attribute capacityL : Real = 50.0;
        attribute fillLevelL : Real = 45.0;
        item solder : MoltenSolder;
        part heatingElement : HeatingElement;
        attribute targetTemp : TemperatureC = 250.0;
        attribute isHeating : Boolean = false;

        action def MeltSolder {
        }
        action def MaintainTemperature {
            in temp : TemperatureC;
        }
    }

    part def CoolingFan {
        attribute airFlow : AirFlowM3PerMin = 5.0;
        attribute isOn : Boolean = false;
        attribute speedRpm : RotationsPerMin = 1800.0;
        attribute maxRpm : RotationsPerMin = 3600.0;

        action def StartFan {
            in targetRpm : RotationsPerMin;
        }
        action def StopFan {
        }
    }

    part def Camera {
        attribute resolution : String = "12MP";
        attribute isCapturing : Boolean = false;
        attribute fieldOfViewDeg : Real = 35.0;
        attribute frameRateFps : Integer = 60;

        action def CaptureImage {
            in boardId : String;
        }
    }

    // =====================================================
    // MAJOR UNIT PART DEFINITIONS
    // =====================================================

    part def ConveyorBelt {
        port inPort : BoardPort;
        port outPort : BoardPort;
        port controlPort : ControlPort;

        attribute beltSpeed : ConveySpeedMmPerSec = 10.0;
        attribute isRunning : Boolean = false;
        attribute beltLengthMm : LengthMm = 1200.0;
        part motor : ConveyorMotor;

        action def LoadBoard {
            in board : PrintedCircuitBoard;
        }

        action def TransportBoard {
            in board : PrintedCircuitBoard;
        }
    }

    part def FluxingUnit {
        port inPort : BoardPort;
        port outPort : BoardPort;
        port controlPort : ControlPort;

        part nozzles : SprayNozzle[4];
        item fluxReservoir : LiquidFlux;
        attribute isFluxing : Boolean = false;
        attribute targetDensity : FluxDensityGPerCm3 = 0.85;
        attribute coverageAreaPct : Percentage = 98.0;

        action def ApplyFlux {
            in board : PrintedCircuitBoard;
        }

        action def CheckFluxLevel {
            return levelOk : Boolean;
        }

        action def RefillFlux {
            in volumeMl : Real;
        }
    }

    part def PreheatingZone {
        port inPort : BoardPort;
        port outPort : BoardPort;
        port controlPort : ControlPort;

        part heatingElements : HeatingElement[3];
        attribute targetTemp : TemperatureC = 100.0;
        attribute rampRateCPerSec : Real = 2.0;
        attribute isHeating : Boolean = false;
        attribute zoneLengthMm : LengthMm = 600.0;

        action def PreheatBoard {
            in board : PrintedCircuitBoard;
        }

        action def RampTemperature {
            in fromTemp : TemperatureC;
            in toTemp : TemperatureC;
        }
    }

    part def WaveSolderingUnit {
        port inPort : BoardPort;
        port outPort : BoardPort;
        port controlPort : ControlPort;

        part solderPot : SolderPot;
        part wavePump : WavePump;
        attribute targetSolderTemp : TemperatureC = 250.0;
        attribute targetWaveHeight : WaveHeightMm = 8.0;
        attribute isSoldering : Boolean = false;
        attribute contactTimeSec : Real = 3.0;

        action def GenerateWave {
        }

        action def SolderBoard {
            in board : PrintedCircuitBoard;
        }

        action def CheckSolderLevel {
            return levelOk : Boolean;
        }
    }

    part def CoolingZone {
        port inPort : BoardPort;
        port outPort : BoardPort;
        port controlPort : ControlPort;

        part fans : CoolingFan[3];
        attribute targetCoolingRateCPerSec : Real = 3.0;
        attribute isCooling : Boolean = false;
        attribute targetExitTemp : TemperatureC = 45.0;
        attribute zoneLengthMm : LengthMm = 500.0;

        action def CoolBoard {
            in board : PrintedCircuitBoard;
        }

        action def AdjustFanSpeed {
            in boardTemp : TemperatureC;
        }
    }

    part def InspectionStation {
        port inPort : BoardPort;
        port acceptPort : BoardPort;
        port rejectPort : BoardPort;
        port resultPort : InspectionResultPort;
        port controlPort : ControlPort;

        part cameras : Camera[2];
        attribute isInspecting : Boolean = false;
        attribute defectThresholdPct : Percentage = 95.0;
        attribute inspectedCount : Integer = 0;
        attribute acceptedCount : Integer = 0;
        attribute rejectedCount : Integer = 0;

        action def InspectBoard {
            in board : PrintedCircuitBoard;
            return result : InspectionResult;
        }

        action def DetectBridges {
            in board : PrintedCircuitBoard;
            return bridgeCount : Integer;
        }

        action def DetectIncompleteJoints {
            in board : PrintedCircuitBoard;
            return incompleteCount : Integer;
        }

        action def SortBoard {
            in board : PrintedCircuitBoard;
            in result : InspectionResult;
        }
    }

    part def ControlSystem {
        port controlPort : ControlPort;

        attribute conveyorSpeed : ConveySpeedMmPerSec = 10.0;
        attribute fluxDensity : FluxDensityGPerCm3 = 0.85;
        attribute preheatingTemp : TemperatureC = 100.0;
        attribute solderWaveHeight : WaveHeightMm = 8.0;
        attribute solderTemp : TemperatureC = 250.0;
        attribute currentFault : FaultType = FaultType::NONE;
        attribute faultDetected : Boolean = false;
        attribute allTempsReached : Boolean = false;
        attribute uptimeHours : Real = 0.0;

        action def StartSystem {
        }

        action def StopSystem {
        }

        action def HandleFault {
            in fault : FaultType;
        }

        action def MonitorParameters {
        }

        action def AdjustConveyorSpeed {
            in newSpeed : ConveySpeedMmPerSec;
        }

        action def AdjustFluxDensity {
            in newDensity : FluxDensityGPerCm3;
        }

        action def AdjustPreheatingTemp {
            in newTemp : TemperatureC;
        }

        action def AdjustWaveHeight {
            in newHeight : WaveHeightMm;
        }
    }

    // =====================================================
    // REQUIREMENTS
    // =====================================================

    requirement def WaveSolderingRequirement {
        doc /* The Automated Wave Soldering System shall reliably solder electronic components onto PCBs in a continuous production line */;
    }

    requirement def ConveyorTransportRequirement :> WaveSolderingRequirement {
        doc /* The system shall transport PCBs through a conveyor belt at a controlled and configurable speed */;
    }

    requirement def FluxingRequirement :> WaveSolderingRequirement {
        doc /* The fluxing unit shall apply a uniform coat of liquid flux to each PCB using spray nozzles to clean metallic surfaces */;
    }

    requirement def PreheatingRequirement :> WaveSolderingRequirement {
        doc /* The preheating zone shall gradually raise PCB temperature using multiple heating elements to prevent thermal shock and activate flux properties */;
    }

    requirement def WaveSolderingProcessRequirement :> WaveSolderingRequirement {
        doc /* The wave soldering unit shall maintain molten solder at a precise temperature and generate a continuous standing wave to bond all exposed leads and pads simultaneously */;
    }

    requirement def CoolingRequirement :> WaveSolderingRequirement {
        doc /* The cooling zone shall cool boards at a controlled rate using fans to ensure solder joint structural integrity */;
    }

    requirement def InspectionRequirement :> WaveSolderingRequirement {
        doc /* The inspection station shall use a vision system with cameras to detect solder defects including bridges and incomplete connections */;
    }

    requirement def SortingRequirement :> WaveSolderingRequirement {
        doc /* The system shall automatically separate boards into accepted and rejected batches based on inspection results */;
    }

    requirement def StateMachineRequirement :> WaveSolderingRequirement {
        doc /* The system shall support idle, preheating, operational, shutdown, and faulted states with defined transitions between them */;
    }

    requirement def ParameterControlRequirement :> WaveSolderingRequirement {
        doc /* The system shall carefully control conveyor speed, flux density, preheating temperature, and solder wave height for consistent quality */;
    }

    requirement req1 : ConveyorTransportRequirement;
    requirement req2 : FluxingRequirement;
    requirement req3 : PreheatingRequirement;
    requirement req4 : WaveSolderingProcessRequirement;
    requirement req5 : CoolingRequirement;
    requirement req6 : InspectionRequirement;
    requirement req7 : SortingRequirement;
    requirement req8 : StateMachineRequirement;
    requirement req9 : ParameterControlRequirement;

    // =====================================================
    // TOP-LEVEL SYSTEM DEFINITION
    // =====================================================

    part def WaveSolderingMachine {
        attribute systemName : String = "AutomatedWaveSolderingSystem";
        attribute serialNumber : String = "WSS-2024-001";
        attribute isOnline : Boolean = false;

        port externalControl : ControlPort;
        port externalResult : InspectionResultPort;

        part conveyorBelt : ConveyorBelt;
        part fluxingUnit : FluxingUnit;
        part preheatingZone : PreheatingZone;
        part waveSolderingUnit : WaveSolderingUnit;
        part coolingZone : CoolingZone;
        part inspectionStation : InspectionStation;
        part controlSystem : ControlSystem;

        // PCB flow connections through processing stages
        connection connect conveyorBelt.outPort to fluxingUnit.inPort;
        connection connect fluxingUnit.outPort to preheatingZone.inPort;
        connection connect preheatingZone.outPort to waveSolderingUnit.inPort;
        connection connect waveSolderingUnit.outPort to coolingZone.inPort;
        connection connect coolingZone.outPort to inspectionStation.inPort;

        // Control signal connections from control system to all units
        connection connect controlSystem.controlPort to conveyorBelt.controlPort;
        connection connect controlSystem.controlPort to fluxingUnit.controlPort;
        connection connect controlSystem.controlPort to preheatingZone.controlPort;
        connection connect controlSystem.controlPort to waveSolderingUnit.controlPort;
        connection connect controlSystem.controlPort to coolingZone.controlPort;
        connection connect controlSystem.controlPort to inspectionStation.controlPort;

        // External interface connections
        connection connect externalControl to controlSystem.controlPort;
        connection connect inspectionStation.resultPort to externalResult;

        // Satisfaction of requirements by sub-parts
        satisfy req1 by conveyorBelt;
        satisfy req2 by fluxingUnit;
        satisfy req3 by preheatingZone;
        satisfy req4 by waveSolderingUnit;
        satisfy req5 by coolingZone;
        satisfy req6 by inspectionStation;
        satisfy req7 by inspectionStation;
        satisfy req8 by WaveSolderingMachine;
        satisfy req9 by controlSystem;

        // State machine governing system operation
        state machine SystemStateMachine {
            state idle {
                entry action {
                    // All subsystems at rest, conveyor stopped, heaters off
                }
                exit action {
                    // Validate system readiness before entering preheating
                }
            }

            state preheating {
                entry action {
                    // Begin heating solder pot to target temperature
                    // Activate preheating zone heating elements
                }
                exit action {
                    // Verify all temperatures have reached setpoints
                }
            }

            state operational {
                entry action {
                    // Start conveyor belt
                    // Activate fluxing spray nozzles
                    // Start wave pump for continuous solder wave
                    // Enable cooling fans
                    // Enable inspection cameras
                }
                exit action {
                    // Stop conveyor after last board clears the line
                }
            }

            state shutdown {
                entry action {
                    // Stop conveyor belt
                    // Stop wave pump
                    // Turn off spray nozzles
                    // Ramp down heating elements gradually
                }
                exit action {
                    // Confirm safe temperatures reached before returning to idle
                }
            }

            state faulted {
                entry action {
                    // Emergency stop all motion
                    // Disable heating elements
                    // Stop wave pump
                    // Record fault details
                    // Await operator intervention
                }
                exit action {
                    // Clear fault condition and reset system
                }
            }

            // Transitions
            transition first idle then preheating when externalControl.enable;
            transition first preheating then operational when waveSolderingUnit.solderPot.solder.temperature >= waveSolderingUnit.targetSolderTemp;
            transition first operational then shutdown when !externalControl.enable;
            transition first operational then faulted when controlSystem.faultDetected;
            transition first preheating then faulted when controlSystem.faultDetected;
            transition first idle then faulted when controlSystem.faultDetected;
            transition first faulted then idle when !controlSystem.faultDetected;
            transition first shutdown then idle;
        }
    }

}
