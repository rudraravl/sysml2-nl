package 'Superfluid Helium System' {
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;

    attribute def Kelvin :> Real;
    attribute def FlowRate :> Real;
    attribute def CoolingPower :> Real;

    item def LiquidHelium;
    item def SuperfluidHelium :> LiquidHelium;

    item def TemperatureReading {
        attribute temperature : Kelvin;
    }
    item def CoolingCommand {
        attribute powerLevel : CoolingPower;
    }
    item def FlowCommand {
        attribute rate : FlowRate;
    }
    item def VortexReport {
        attribute count : Integer;
    }

    attribute def StartCommand;
    attribute def ShutdownCommand;
    attribute def WarmupCompleteSignal;
    attribute def TemperatureBelowCritical;

    part def CryogenicCooler {
        port cmdIn { in cmd : CoolingCommand; }
        port coolantOut { out coolant : LiquidHelium; }
        attribute currentPower : CoolingPower;
        action activate { in cmd : CoolingCommand; }
        action deactivate;
    }

    part def HeliumReservoir {
        port coolantIn { in coolant : LiquidHelium; }
        port fluidIn { in fluid : SuperfluidHelium; }
        port fluidOut { out fluid : SuperfluidHelium; }
        attribute currentTemp : Kelvin;
        attribute isSuperfluid : Boolean;
        action updateState;
    }

    part def TemperatureSensor {
        port readingOut { out reading : TemperatureReading; }
        attribute measuredTemp : Kelvin;
        action measure { out reading : TemperatureReading; }
    }

    part def FlowController {
        port cmdIn { in cmd : FlowCommand; }
        port fluidIn { in fluid : SuperfluidHelium; }
        port fluidOut { out fluid : SuperfluidHelium; }
        attribute currentFlowRate : FlowRate;
        action regulate { in cmd : FlowCommand; }
    }

    part def PersistentCurrentLoop {
        port fluidIn { in fluid : SuperfluidHelium; }
        port fluidOut { out fluid : SuperfluidHelium; }
        attribute isCirculating : Boolean;
        action startCirculation;
        action stopCirculation;
    }

    part def QuantumVortexDetector {
        port fluidIn { in fluid : SuperfluidHelium; }
        port fluidOut { out fluid : SuperfluidHelium; }
        port vortexOut { out report : VortexReport; }
        action detectVortices { out report : VortexReport; }
    }

    part def SystemController {
        port tempIn { in reading : TemperatureReading; }
        port vortexIn { in report : VortexReport; }
        port coolerCmdOut { out cmd : CoolingCommand; }
        port flowCmdOut { out cmd : FlowCommand; }
        action evaluate {
            in reading : TemperatureReading;
            in report : VortexReport;
            out coolCmd : CoolingCommand;
            out flowCmd : FlowCommand;
        }
    }

    requirement def SuperfluidityRequirement {
        attribute criticalTemperature : Kelvin = 2.17;
        attribute zeroViscosity : Boolean = true;
    }

    requirement def CoolingRequirement :> SuperfluidityRequirement {
        attribute targetTemperature : Kelvin = 2.17;
    }

    requirement def FlowControlRequirement :> SuperfluidityRequirement {
        attribute maxFlowRate : FlowRate;
    }

    requirement def VortexDetectionRequirement :> SuperfluidityRequirement {
        attribute minDetectionCount : Integer = 0;
    }

    requirement def ResearchRequirement :> SuperfluidityRequirement {
    }

    part def SuperfluidSystem {
        part cooler : CryogenicCooler;
        part reservoir : HeliumReservoir;
        part controller : SystemController;
        part tempSensor : TemperatureSensor;
        part flowCtrl : FlowController;
        part currentLoop : PersistentCurrentLoop;
        part vortexDet : QuantumVortexDetector;

        flow coolantFlow of LiquidHelium
            from cooler.coolantOut.coolant to reservoir.coolantIn.coolant;
        flow tempFlow of TemperatureReading
            from tempSensor.readingOut.reading to controller.tempIn.reading;
        flow coolerCmdFlow of CoolingCommand
            from controller.coolerCmdOut.cmd to cooler.cmdIn.cmd;
        flow flowCmdFlow of FlowCommand
            from controller.flowCmdOut.cmd to flowCtrl.cmdIn.cmd;
        flow superfluidFeed of SuperfluidHelium
            from reservoir.fluidOut.fluid to flowCtrl.fluidIn.fluid;
        flow loopFeed of SuperfluidHelium
            from flowCtrl.fluidOut.fluid to currentLoop.fluidIn.fluid;
        flow detectorFeed of SuperfluidHelium
            from currentLoop.fluidOut.fluid to vortexDet.fluidIn.fluid;
        flow returnFlow of SuperfluidHelium
            from vortexDet.fluidOut.fluid to reservoir.fluidIn.fluid;
        flow vortexReportFlow of VortexReport
            from vortexDet.vortexOut.report to controller.vortexIn.report;

        satisfy SuperfluidityRequirement;
        satisfy CoolingRequirement;
        satisfy FlowControlRequirement;
        satisfy VortexDetectionRequirement;
        satisfy ResearchRequirement;

        state lifecycle {
            entry; then off;
            state off;
            accept StartCommand then cooling;
            state cooling {
                do action activateCooling { /* ... */ }
            }
            accept TemperatureBelowCritical then superfluid;
            state superfluid {
                do action maintainSuperfluidity { /* ... */ }
                do action detectVortices { /* ... */ }
            }
            accept ShutdownCommand then warmup;
            state warmup {
                do action deactivateCooling { /* ... */ }
            }
            accept WarmupCompleteSignal then off;
        }
    }
}
