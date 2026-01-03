package 'Jabsco Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Pressure :> ISQ::pressure {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::PressureUnit;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::VolumePerTimeUnit;
    }

    attribute def RotationalSpeed {
        attribute value : Real;
        attribute unit : String = "rpm";
    }

    attribute def Voltage {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def Power :> ISQ::power {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::PowerUnit;
    }

    item def Fluid {
        attribute density : Real;
        attribute viscosity : Real;
        attribute temperature : ISQ::TemperatureValue;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Real;
    }

    port def FluidPort {
        attribute portPressure : Pressure;
        out item fluidOut : Fluid;
        in item fluidIn : Fluid;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    part def JabscoPump {
        doc /* 
         * Jabsco self-priming positive displacement pump
         * Model: 50880-1000 series
         */

        attribute modelNumber : String = "50880-1000";
        attribute maxFlowRate : FlowRate {
            attribute :>> num = 19.0;
            attribute :>> mRef = SI::L / SI::min;
        }
        attribute maxPressure : Pressure {
            attribute :>> num = 3.4;
            attribute :>> mRef = SI::bar;
        }
        attribute ratedVoltage : Voltage {
            attribute value = 12.0;
        }
        attribute ratedPower : Power {
            attribute :>> num = 60.0;
            attribute :>> mRef = SI::W;
        }
        attribute efficiency : Real = 0.75;
        attribute currentSpeed : RotationalSpeed;
        attribute isPrimed : Boolean = false;

        port suctionPort : ~FluidPort {
            doc /* Inlet port for fluid suction */
        }

        port dischargePort : FluidPort {
            doc /* Outlet port for pressurized fluid */
        }

        port powerInput : ~PowerPort {
            doc /* Electrical power connection */
        }

        part impellerAssembly {
            attribute numberOfVanes : Integer = 6;
            attribute diameter : ISQ::LengthValue {
                attribute :>> num = 50.0;
                attribute :>> mRef = SI::mm;
            }
            attribute material : String = "Nitrile Rubber";
        }

        part pumpHousing {
            attribute material : String = "Bronze";
            attribute inletSize : ISQ::LengthValue {
                attribute :>> num = 19.0;
                attribute :>> mRef = SI::mm;
            }
            attribute outletSize : ISQ::LengthValue {
                attribute :>> num = 19.0;
                attribute :>> mRef = SI::mm;
            }
        }

        part dcMotor {
            attribute motorType : String = "Permanent Magnet DC";
            attribute nominalSpeed : RotationalSpeed {
                attribute value = 3000.0;
            }
            attribute torque : Real;
        }

        part mechanicalSeal {
            attribute sealType : String = "Lip Seal";
            attribute material : String = "Viton";
        }
    }

    part def FluidReservoir {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;
        attribute minLevel : ISQ::VolumeValue;

        port outlet : FluidPort;

        item storedFluid : Fluid {
            attribute volume : ISQ::VolumeValue = currentLevel;
        }
    }

    part def FluidDestination {
        attribute capacity : ISQ::VolumeValue;
        attribute currentLevel : ISQ::VolumeValue;

        port inlet : ~FluidPort;

        item receivedFluid : Fluid {
            attribute volume : ISQ::VolumeValue = currentLevel;
        }
    }

    part def PipeSegment {
        attribute length : ISQ::LengthValue;
        attribute innerDiameter : ISQ::LengthValue;
        attribute material : String;

        port inlet : ~FluidPort;
        port outlet : FluidPort;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure;
        attribute isOpen : Boolean = false;

        port inlet : ~FluidPort;
        port outlet : FluidPort;
    }

    part def StrainerFilter {
        attribute meshSize : ISQ::LengthValue;
        attribute pressureDrop : Pressure;

        port inlet : ~FluidPort;
        port outlet : FluidPort;
    }

    part def FlowMeter {
        attribute reading : FlowRate;
        attribute accuracy : Real = 0.05;

        port measurePort : ~FluidPort;
    }

    part def PressureSensor {
        attribute reading : Pressure;
        attribute accuracy : Real = 0.02;

        port sensePort : ~FluidPort;
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage {
            attribute value = 12.0;
        }
        attribute maxCurrent : Real = 10.0;

        port powerOut : ~PowerPort;
    }

    action def PrimePump {
        in pump : JabscoPump;
        out primedPump : JabscoPump;
        doc /* Remove air from pump chamber and establish fluid flow */
    }

    action def StartPump {
        in pump : JabscoPump;
        in targetFlowRate : FlowRate;
        out runningPump : JabscoPump;
    }

    action def StopPump {
        in pump : JabscoPump;
        out stoppedPump : JabscoPump;
    }

    action def TransferFluid {
        in fluidIn : Fluid;
        out fluidOut : Fluid;
        in pumpSpeed : RotationalSpeed;
        in efficiency : Real;
    }

    action def MonitorPerformance {
        in flowReading : FlowRate;
        in pressureReading : Pressure;
        out performanceStatus : String;
    }

    state def PumpOperationStates {
        entry; then idle;

        state idle {
            doc /* Pump is off and stationary */
        }

        transition idle_to_priming
            first idle
            accept StartCommand
            then priming;

        state priming {
            doc /* Pump is self-priming to remove air */
            entry action primingAction : PrimePump;
        }

        transition priming_to_running
            first priming
            if primingAction.primedPump.isPrimed
            then running;

        state running {
            doc /* Pump is operating at normal speed */
            entry action startAction : StartPump;
            do action transferAction : TransferFluid;
            do action monitorAction : MonitorPerformance;
        }

        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;

        state stopping {
            doc /* Pump is decelerating to stop */
            entry action stopAction : StopPump;
        }

        transition stopping_to_idle
            first stopping
            if stopAction.stoppedPump.currentSpeed.value == 0.0
            then idle;

        transition running_to_fault
            first running
            accept FaultDetected
            then fault;

        state fault {
            doc /* Pump has encountered an error */
        }

        transition fault_to_idle
            first fault
            accept ResetCommand
            then idle;
    }

    requirement def FlowRateRequirement {
        doc /* System shall maintain specified flow rate */
        id = "REQ-FLOW-001";

        attribute minFlowRate : FlowRate {
            attribute :>> num = 10.0;
            attribute :>> mRef = SI::L / SI::min;
        }
        attribute nominalFlowRate : FlowRate {
            attribute :>> num = 15.0;
            attribute :>> mRef = SI::L / SI::min;
        }

        require constraint {
            doc /* Flow rate must meet minimum requirement */
            nominalFlowRate.num >= minFlowRate.num
        }
    }

    requirement def PressureRequirement {
        doc /* System shall operate within pressure limits */
        id = "REQ-PRESS-001";

        attribute maxOperatingPressure : Pressure {
            attribute :>> num = 3.4;
            attribute :>> mRef = SI::bar;
        }

        require constraint {
            doc /* Operating pressure must not exceed pump rating */
            maxOperatingPressure.num <= 3.4
        }
    }

    requirement def ReliabilityRequirement {
        doc /* System shall operate reliably */
        id = "REQ-REL-001";

        attribute mtbf : ISQ::TimeValue {
            attribute :>> num = 5000.0;
            attribute :>> mRef = SI::h;
        }
    }

    requirement def SafetyRequirement {
        doc /* System shall include safety features */
        id = "REQ-SAFE-001";

        require checkValvePresent {
            doc /* Check valve shall prevent backflow */
        }

        require strainerPresent {
            doc /* Strainer shall protect pump from debris */
        }
    }

    requirement def SystemRequirements {
        doc /* Top-level requirements for pumping subsystem */
        id = "REQ-SYS-001";

        require flowReq : FlowRateRequirement;
        require pressReq : PressureRequirement;
        require relReq : ReliabilityRequirement;
        require safeReq : SafetyRequirement;
    }

    part pumpingSubsystem {
        doc /* 
         * Complete pumping subsystem with Jabsco pump,
         * fluid source, destination, and monitoring equipment
         */

        part sourceReservoir : FluidReservoir {
            attribute :>> capacity {
                attribute :>> num = 100.0;
                attribute :>> mRef = SI::L;
            }
            attribute :>> currentLevel {
                attribute :>> num = 80.0;
                attribute :>> mRef = SI::L;
            }
            attribute :>> minLevel {
                attribute :>> num = 10.0;
                attribute :>> mRef = SI::L;
            }

            item :>> storedFluid {
                attribute :>> density = 1000.0;
                attribute :>> viscosity = 0.001;
                attribute :>> temperature {
                    attribute :>> num = 20.0;
                    attribute :>> mRef = SI::'°C';
                }
            }
        }

        part suctionStrainer : StrainerFilter {
            attribute :>> meshSize {
                attribute :>> num = 0.5;
                attribute :>> mRef = SI::mm;
            }
            attribute :>> pressureDrop {
                attribute :>> num = 0.05;
                attribute :>> mRef = SI::bar;
            }
        }

        part suctionPipe : PipeSegment {
            attribute :>> length {
                attribute :>> num = 1.5;
                attribute :>> mRef = SI::m;
            }
            attribute :>> innerDiameter {
                attribute :>> num = 19.0;
                attribute :>> mRef = SI::mm;
            }
            attribute :>> material = "Reinforced Rubber";
        }

        part jabscoPump : JabscoPump {
            attribute :>> isPrimed = true;
            attribute :>> currentSpeed {
                attribute value = 3000.0;
            }
        }

        part dischargePipe : PipeSegment {
            attribute :>> length {
                attribute :>> num = 2.0;
                attribute :>> mRef = SI::m;
            }
            attribute :>> innerDiameter {
                attribute :>> num = 19.0;
                attribute :>> mRef = SI::mm;
            }
            attribute :>> material = "Reinforced Rubber";
        }

        part dischargeCheckValve : CheckValve {
            attribute :>> crackingPressure {
                attribute :>> num = 0.1;
                attribute :>> mRef = SI::bar;
            }
        }

        part flowSensor : FlowMeter {
            attribute :>> accuracy = 0.05;
        }

        part pressureSensor : PressureSensor {
            attribute :>> accuracy = 0.02;
        }

        part destinationTank : FluidDestination {
            attribute :>> capacity {
                attribute :>> num = 50.0;
                attribute :>> mRef = SI::L;
            }
            attribute :>> currentLevel {
                attribute :>> num = 5.0;
                attribute :>> mRef = SI::L;
            }
        }

        part powerSupply : PowerSupply {
            attribute :>> outputVoltage {
                attribute value = 12.0;
            }
            attribute :>> maxCurrent = 10.0;
        }

        flow of fluid : Fluid
            from sourceReservoir.outlet.fluidOut
            to suctionStrainer.inlet.fluidIn;

        flow of fluid : Fluid
            from suctionStrainer.outlet.fluidOut
            to suctionPipe.inlet.fluidIn;

        flow of fluid : Fluid
            from suctionPipe.outlet.fluidOut
            to jabscoPump.suctionPort.fluidIn;

        flow of fluid : Fluid
            from jabscoPump.dischargePort.fluidOut
            to dischargePipe.inlet.fluidIn;

        flow of fluid : Fluid
            from dischargePipe.outlet.fluidOut
            to dischargeCheckValve.inlet.fluidIn;

        flow of fluid : Fluid
            from dischargeCheckValve.outlet.fluidOut
            to flowSensor.measurePort.fluidIn;

        flow of fluid : Fluid
            from flowSensor.measurePort.fluidOut
            to destinationTank.inlet.fluidIn;

        binding pressureSensor.sensePort.portPressure = dischargePipe.outlet.portPressure;

        connection powerConnection
            from powerSupply.powerOut
            to jabscoPump.powerInput;

        perform action pumpOperation {
            action operateStateMachine : PumpOperationStates;
        }
    }

    requirement systemReqs : SystemRequirements {
        subject pumpingSubsystem;

        require :>> flowReq {
            attribute :>> nominalFlowRate {
                attribute :>> num = 15.0;
            }
        }

        require :>> pressReq {
            attribute :>> maxOperatingPressure {
                attribute :>> num = 3.0;
            }
        }
    }

    satisfy systemReqs by pumpingSubsystem;
}
