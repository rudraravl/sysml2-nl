package WaveSolderingSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def Speed :> Real {
        unit = "m/min";
    }

    attribute def FlowRate :> Real {
        unit = "L/min";
    }

    attribute def Length :> Real {
        unit = "mm";
    }

    attribute def Mass :> Real {
        unit = "kg";
    }

    attribute def Power :> Real {
        unit = "kW";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    enum def BoardState {
        enum unprocessed;
        enum fluxed;
        enum preheated;
        enum soldered;
        enum cooled;
        enum rejected;
        enum accepted;
    }

    enum def MachineMode {
        enum stopped;
        enum standby;
        enum heating;
        enum ready;
        enum processing;
        enum faulted;
        enum emergencyStop;
    }

    enum def FaultCode {
        enum noFault;
        enum solderTemperatureLow;
        enum solderTemperatureHigh;
        enum conveyorJam;
        enum fluxLevelLow;
        enum nitrogenPressureLow;
        enum exhaustFlowLow;
        enum emergencyStopPressed;
    }

    item def PrintedCircuitAssembly {
        attribute boardId : String;
        attribute length : Length;
        attribute width : Length;
        attribute thickness : Length;
        attribute state : BoardState;
        attribute topSideComponentClearance : Length;
        attribute requiredSolderCoverage : Percent;
    }

    item def LiquidFlux {
        attribute solidsContent : Percent;
        attribute density : Real;
        attribute flowRate : FlowRate;
    }

    item def MoltenSolder {
        attribute alloyName : String;
        attribute tinContent : Percent;
        attribute silverContent : Percent;
        attribute copperContent : Percent;
        attribute temperature : Temperature;
        attribute waveHeight : Length;
    }

    item def HeatEnergy {
        attribute thermalPower : Power;
        attribute exposureTime : TimeDuration;
    }

    item def NitrogenGas {
        attribute purity : Percent;
        attribute flowRate : FlowRate;
    }

    item def FumeExhaust {
        attribute flowRate : FlowRate;
        attribute particulateLoad : Real;
    }

    item def InspectionResult {
        attribute boardId : String;
        attribute solderCoverage : Percent;
        attribute bridgeCount : Integer;
        attribute insufficientJointCount : Integer;
        attribute accepted : Boolean;
    }

    item def ControlCommand {
        attribute requestedMode : MachineMode;
        attribute conveyorSpeedSetpoint : Speed;
        attribute solderTemperatureSetpoint : Temperature;
        attribute waveHeightSetpoint : Length;
        attribute fluxFlowSetpoint : FlowRate;
    }

    item def MachineStatus {
        attribute actualMode : MachineMode;
        attribute activeFault : FaultCode;
        attribute solderTemperature : Temperature;
        attribute conveyorSpeed : Speed;
        attribute fluxLevel : Percent;
        attribute exhaustFlow : FlowRate;
    }

    port def BoardInPort {
        in item board : PrintedCircuitAssembly;
    }

    port def BoardOutPort {
        out item board : PrintedCircuitAssembly;
    }

    port def FluxSupplyPort {
        in item flux : LiquidFlux;
    }

    port def SolderSupplyPort {
        in item solder : MoltenSolder;
    }

    port def NitrogenSupplyPort {
        in item nitrogen : NitrogenGas;
    }

    port def ExhaustPort {
        out item exhaust : FumeExhaust;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : MachineStatus;
    }

    port def InspectionPort {
        out item result : InspectionResult;
    }

    action def ApplyFlux {
        in item rawBoard : PrintedCircuitAssembly;
        in item flux : LiquidFlux;
        out item fluxedBoard : PrintedCircuitAssembly;

        first start;
        then atomizeFlux;
        then coatBottomSide;
        then verifyCoverage;
        then done;

        action atomizeFlux {
            attribute targetFlow : FlowRate = 0.18;
        }

        action coatBottomSide {
            attribute sprayWidth : Length = 260.0;
        }

        action verifyCoverage {
            attribute minimumFluxCoverage : Percent = 92.0;
        }
    }

    action def PreheatBoard {
        in item fluxedBoard : PrintedCircuitAssembly;
        in item heat : HeatEnergy;
        out item preheatedBoard : PrintedCircuitAssembly;

        first start;
        then rampBoardTemperature;
        then activateFlux;
        then stabilizeBoard;
        then done;

        action rampBoardTemperature {
            attribute targetTopSideTemperature : Temperature = 115.0;
            attribute maximumRampRate : Real = 2.0;
        }

        action activateFlux {
            attribute minimumExposureTime : TimeDuration = 35.0;
        }
    }

    action def FormSolderWave {
        in item solder : MoltenSolder;
        out item conditionedSolder : MoltenSolder;

        first start;
        then heatSolderBath;
        then circulatePump;
        then stabilizeWave;
        then done;

        action heatSolderBath {
            attribute nominalTemperature : Temperature = 255.0;
            attribute allowableDeviation : Temperature = 5.0;
        }

        action circulatePump {
            attribute nominalWaveHeight : Length = 8.0;
        }
    }

    action def SolderBoard {
        in item preheatedBoard : PrintedCircuitAssembly;
        in item conditionedSolder : MoltenSolder;
        out item solderedBoard : PrintedCircuitAssembly;

        first start;
        then contactWave;
        then wetThroughHoleLeads;
        then drainExcessSolder;
        then done;

        action contactWave {
            attribute contactTime : TimeDuration = 3.2;
            attribute conveyorSpeed : Speed = 1.25;
        }

        action wetThroughHoleLeads {
            attribute minimumSolderTemperature : Temperature = 250.0;
        }
    }

    action def CoolAndInspect {
        in item solderedBoard : PrintedCircuitAssembly;
        out item finishedBoard : PrintedCircuitAssembly;
        out item result : InspectionResult;

        first start;
        then forcedAirCooling;
        then opticalInspection;
        then classifyBoard;
        then done;

        action forcedAirCooling {
            attribute maximumExitTemperature : Temperature = 55.0;
        }

        action opticalInspection {
            attribute minimumAcceptableCoverage : Percent = 98.0;
            attribute maximumBridgeCount : Integer = 0;
        }
    }

    state def WaveSolderingOperatingState {
        entry action initializeStatus;

        state Off;
        state Standby;
        state Heating;
        state Ready;
        state Processing;
        state Fault;
        state EmergencyStop;

        first Off;

        transition powerOn
            first Off
            then Standby;

        transition beginHeating
            first Standby
            then Heating;

        transition temperatureStable
            first Heating
            then Ready
            guard solderBathTemperature >= 250.0 and solderBathTemperature <= 260.0;

        transition startProduction
            first Ready
            then Processing;

        transition stopProduction
            first Processing
            then Ready;

        transition enterFault
            first Processing
            then Fault
            guard activeFault != FaultCode::noFault;

        transition faultFromHeating
            first Heating
            then Fault
            guard activeFault != FaultCode::noFault;

        transition resetFault
            first Fault
            then Standby
            guard activeFault == FaultCode::noFault;

        transition emergencyStopFromAny
            first Off
            then EmergencyStop
            guard emergencyStopSignal == true;

        transition emergencyStopReset
            first EmergencyStop
            then Standby
            guard emergencyStopSignal == false;

        attribute solderBathTemperature : Temperature;
        attribute activeFault : FaultCode;
        attribute emergencyStopSignal : Boolean;
    }

    part def ConveyorSubsystem {
        port boardIn : BoardInPort;
        port boardOut : BoardOutPort;
        port statusOut : StatusPort;

        attribute speedSetpoint : Speed = 1.25;
        attribute actualSpeed : Speed;
        attribute railWidth : Length = 180.0;
        attribute maximumBoardLength : Length = 420.0;
        attribute jamDetected : Boolean;

        perform action transportBoard {
            in item board : PrintedCircuitAssembly;
            out item transportedBoard : PrintedCircuitAssembly;
        }
    }

    part def FluxerSubsystem {
        port boardIn : BoardInPort;
        port boardOut : BoardOutPort;
        port fluxIn : FluxSupplyPort;

        attribute fluxLevel : Percent;
        attribute nozzlePressure : Real;
        attribute nominalFluxFlow : FlowRate = 0.18;
        attribute minimumFluxLevel : Percent = 15.0;

        perform action applyFlux : ApplyFlux;
    }

    part def PreheaterSubsystem {
        port boardIn : BoardInPort;
        port boardOut : BoardOutPort;

        attribute zone1Temperature : Temperature = 95.0;
        attribute zone2Temperature : Temperature = 115.0;
        attribute zone3Temperature : Temperature = 130.0;
        attribute heaterPower : Power = 7.5;
        attribute maximumBoardExitTemperature : Temperature = 130.0;

        perform action preheat : PreheatBoard;
    }

    part def SolderPotSubsystem {
        port boardIn : BoardInPort;
        port boardOut : BoardOutPort;
        port solderIn : SolderSupplyPort;
        port nitrogenIn : NitrogenSupplyPort;
        port exhaustOut : ExhaustPort;

        attribute bathCapacity : Mass = 360.0;
        attribute bathTemperature : Temperature = 255.0;
        attribute waveHeight : Length = 8.0;
        attribute pumpPower : Power = 1.8;
        attribute oxideDrossLimit : Mass = 2.5;
        attribute nitrogenPurityMinimum : Percent = 99.95;

        perform action formWave : FormSolderWave;
        perform action solderBoard : SolderBoard;
    }

    part def CoolingSubsystem {
        port boardIn : BoardInPort;
        port boardOut : BoardOutPort;

        attribute fanPower : Power = 1.2;
        attribute targetExitTemperature : Temperature = 55.0;
        attribute coolingLength : Length = 900.0;

        perform action coolBoard {
            in item solderedBoard : PrintedCircuitAssembly;
            out item cooledBoard : PrintedCircuitAssembly;
        }
    }

    part def InspectionSubsystem {
        port boardIn : BoardInPort;
        port boardOut : BoardOutPort;
        port resultOut : InspectionPort;

        attribute minimumSolderCoverage : Percent = 98.0;
        attribute maximumBridgeCount : Integer = 0;
        attribute maximumInsufficientJointCount : Integer = 0;

        perform action inspect : CoolAndInspect;
    }

    part def ControlSubsystem {
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute mode : MachineMode = MachineMode::stopped;
        attribute activeFault : FaultCode = FaultCode::noFault;
        attribute emergencyStopSignal : Boolean = false;
        attribute solderTemperatureSetpoint : Temperature = 255.0;
        attribute conveyorSpeedSetpoint : Speed = 1.25;
        attribute fluxFlowSetpoint : FlowRate = 0.18;
        attribute waveHeightSetpoint : Length = 8.0;

        exhibit state operatingState : WaveSolderingOperatingState;

        perform action monitorProcess {
            out item status : MachineStatus;
        }

        perform action regulateTemperature {
            attribute proportionalGain : Real = 2.4;
            attribute maximumHeaterPower : Power = 12.0;
        }

        perform action regulateWaveHeight {
            attribute pumpSpeedCommand : Percent;
        }
    }

    part def SafetySubsystem {
        port statusOut : StatusPort;

        attribute emergencyStopPressed : Boolean = false;
        attribute guardDoorClosed : Boolean = true;
        attribute exhaustFlowMinimum : FlowRate = 120.0;
        attribute nitrogenPressureMinimum : Real = 4.5;

        perform action evaluateSafetyInterlocks {
            out item status : MachineStatus;
        }
    }

    part def WaveSolderingMachine {
        port boardInput : BoardInPort;
        port boardOutput : BoardOutPort;
        port fluxSupply : FluxSupplyPort;
        port solderSupply : SolderSupplyPort;
        port nitrogenSupply : NitrogenSupplyPort;
        port exhaustDischarge : ExhaustPort;
        port commandInput : CommandPort;
        port machineStatus : StatusPort;
        port inspectionOutput : InspectionPort;

        attribute nominalThroughput : Real = 180.0;
        attribute nominalConveyorSpeed : Speed = 1.25;
        attribute nominalSolderTemperature : Temperature = 255.0;
        attribute nominalPreheatExitTemperature : Temperature = 115.0;
        attribute primaryFunction : String = "Continuously transports printed circuit assemblies through fluxing, preheating, molten solder wave contact, cooling, and inspection to create reliable solder joints on through-hole electronic assemblies.";

        part conveyor : ConveyorSubsystem;
        part fluxer : FluxerSubsystem;
        part preheater : PreheaterSubsystem;
        part solderPot : SolderPotSubsystem;
        part cooler : CoolingSubsystem;
        part inspector : InspectionSubsystem;
        part controller : ControlSubsystem;
        part safety : SafetySubsystem;

        connect boardInput to conveyor.boardIn;
        connect conveyor.boardOut to fluxer.boardIn;
        connect fluxer.boardOut to preheater.boardIn;
        connect preheater.boardOut to solderPot.boardIn;
        connect solderPot.boardOut to cooler.boardIn;
        connect cooler.boardOut to inspector.boardIn;
        connect inspector.boardOut to boardOutput;

        connect fluxSupply to fluxer.fluxIn;
        connect solderSupply to solderPot.solderIn;
        connect nitrogenSupply to solderPot.nitrogenIn;
        connect solderPot.exhaustOut to exhaustDischarge;

        connect commandInput to controller.commandIn;
        connect controller.statusOut to machineStatus;
        connect safety.statusOut to machineStatus;
        connect inspector.resultOut to inspectionOutput;

        perform action processAssembly {
            in item rawAssembly : PrintedCircuitAssembly;
            in item flux : LiquidFlux;
            in item solder : MoltenSolder;
            in item nitrogen : NitrogenGas;
            out item completedAssembly : PrintedCircuitAssembly;
            out item inspection : InspectionResult;

            first receiveBoard;
            then applyFlux;
            then preheat;
            then formWave;
            then solder;
            then coolAndInspect;
            then dischargeBoard;

            action receiveBoard {
                out item acceptedRawAssembly : PrintedCircuitAssembly;
            }

            action applyFlux : ApplyFlux;

            action preheat : PreheatBoard;

            action formWave : FormSolderWave;

            action solder : SolderBoard;

            action coolAndInspect : CoolAndInspect;

            action dischargeBoard {
                in item finishedBoard : PrintedCircuitAssembly;
                out item completedAssembly : PrintedCircuitAssembly;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The wave soldering system shall provide the primary function of forming repeatable solder joints on printed circuit assemblies by applying flux, preheating the assembly, contacting selected surfaces with a controlled molten solder wave, cooling the assembly, and reporting inspection status. */
    }

    requirement def ThroughputRequirement {
        attribute minimumThroughput : Real = 150.0;
        doc /* The system shall process at least 150 printed circuit assemblies per hour when operating in steady production mode with boards no longer than 250 mm. */
    }

    requirement def SolderTemperatureRequirement {
        attribute lowerLimit : Temperature = 250.0;
        attribute upperLimit : Temperature = 260.0;
        doc /* The solder pot shall maintain molten solder temperature between 250 degC and 260 degC during board contact with the solder wave. */
    }

    requirement def ConveyorSpeedRequirement {
        attribute lowerLimit : Speed = 0.8;
        attribute upperLimit : Speed = 1.6;
        doc /* The conveyor shall transport assemblies through the solder wave at an adjustable speed between 0.8 m/min and 1.6 m/min. */
    }

    requirement def FluxCoverageRequirement {
        attribute minimumCoverage : Percent = 92.0;
        doc /* The fluxer shall apply flux to at least 92 percent of the solder-side target area before preheating. */
    }

    requirement def InspectionRequirement {
        attribute minimumSolderCoverage : Percent = 98.0;
        attribute maximumBridgeCount : Integer = 0;
        attribute maximumInsufficientJointCount : Integer = 0;
        doc /* The inspection subsystem shall classify an assembly as accepted only when solder coverage is at least 98 percent, bridge count is zero, and insufficient joint count is zero. */
    }

    requirement def SafetyRequirement {
        doc /* The system shall enter emergency stop mode and remove conveyor, pump, and heater actuation when an emergency stop input is active or a safety guard is open. */
    }

    requirement def ExhaustRequirement {
        attribute minimumExhaustFlow : FlowRate = 120.0;
        doc /* The exhaust subsystem shall remove flux fumes and solder emissions with at least 120 L/min equivalent extraction flow while soldering is active. */
    }

    satisfy PrimaryFunctionRequirement by WaveSolderingMachine;
    satisfy ThroughputRequirement by WaveSolderingMachine;
    satisfy SolderTemperatureRequirement by SolderPotSubsystem;
    satisfy ConveyorSpeedRequirement by ConveyorSubsystem;
    satisfy FluxCoverageRequirement by FluxerSubsystem;
    satisfy InspectionRequirement by InspectionSubsystem;
    satisfy SafetyRequirement by SafetySubsystem;
    satisfy ExhaustRequirement by SolderPotSubsystem;

    part waveSolderingLine : WaveSolderingMachine {
        attribute nominalThroughput = 180.0;
        attribute nominalConveyorSpeed = 1.25;
        attribute nominalSolderTemperature = 255.0;
        attribute nominalPreheatExitTemperature = 115.0;
    }
}