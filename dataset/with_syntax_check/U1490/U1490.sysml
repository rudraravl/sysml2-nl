package SafetyValveSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    enum def ValvePosition {
        fullyClosed;
        opening;
        fullyOpen;
        closing;
    }

    enum def SystemStatus {
        normal;
        warning;
        critical;
        relieving;
    }

    port def PressurePort {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    port def FlowPort {
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }

    item def ProcessFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute density : DensityValue;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute accuracy : Real;
        port sensorPort : PressurePort;
    }

    part def SpringMechanism {
        attribute springConstant : Real;
        attribute preloadForce : ForceValue;
        attribute compressionDistance : LengthValue;
    }

    part def ValveDisc {
        attribute seatDiameter : LengthValue;
        attribute liftHeight : LengthValue;
        attribute effectiveArea : AreaValue;
    }

    part def ValveBody {
        attribute inletDiameter : LengthValue;
        attribute outletDiameter : LengthValue;
        attribute ratedCapacity : VolumeFlowRateValue;
        port inlet : FlowPort;
        port outlet : FlowPort;
    }

    action def MonitorPressure {
        in currentPressure : PressureValue;
        in setPressure : PressureValue;
        in blowdownPressure : PressureValue;
        out status : SystemStatus;
        out shouldOpen : Boolean;
        out shouldClose : Boolean;
    }

    action def SafetyValveControl {
        first start;
        then merge continuousMonitoring;
        then action monitor : MonitorPressure {
            in systemPressure : PressureValue;
            in setPoint : PressureValue;
            in blowdown : PressureValue;
            out currentStatus : SystemStatus;
            out openCommand : Boolean;
            out closeCommand : Boolean;
        }
        then decide;
            if monitor.currentStatus == SystemStatus::critical then initiateRelief;
            if monitor.currentStatus == SystemStatus::relieving and monitor.closeCommand then initiateClosing;
            if monitor.currentStatus == SystemStatus::normal then maintainClosed;
            if monitor.currentStatus == SystemStatus::warning then continuousMonitoring;
        action initiateRelief {
            out reliefActive = true;
        }
        then continuousMonitoring;
        action initiateClosing {
            out reliefActive = false;
        }
        then continuousMonitoring;
        action maintainClosed {
            out reliefActive = false;
        }
        then continuousMonitoring;
    }

    part def SafetyValve {
        attribute setPressure : PressureValue;
        attribute blowdownPressure : PressureValue;
        attribute operatingPressure : PressureValue;
        attribute position : ValvePosition;
        attribute relievingCapacity : VolumeFlowRateValue;

        part sensor : PressureSensor {
            attribute :>> accuracy = 0.5;
        }

        part spring : SpringMechanism {
            attribute :>> springConstant : Real;
            attribute :>> preloadForce : ForceValue;
        }

        part disc : ValveDisc {
            attribute :>> seatDiameter : LengthValue;
            attribute :>> liftHeight : LengthValue;
        }

        part body : ValveBody {
            attribute :>> inletDiameter : LengthValue;
            attribute :>> outletDiameter : LengthValue;
            attribute :>> ratedCapacity : VolumeFlowRateValue;
        }

        connection sensorConnection connect body.inlet to sensor.sensorPort;

        assert constraint setPressureValid {
            setPressure > 0.0 [SI::kPa]
        }

        assert constraint blowdownValid {
            blowdownPressure < setPressure and blowdownPressure > 0.0 [SI::kPa]
        }

        state valveStateMachine {
            entry; then seated;

            state seated {
                entry action assignSeated { position := ValvePosition::fullyClosed; }
            }

            transition seatedToOpening
                first seated
                accept pressureRise : ISQ::PressureValue
                if pressureRise >= setPressure
                then opening;

            state opening {
                entry action assignOpening { position := ValvePosition::opening; }
                do action actuateOpen {
                    out liftDistance = disc.liftHeight;
                }
            }

            transition openingToRelieving
                first opening
                accept fullyLifted : Boolean
                if fullyLifted
                then relieving;

            state relieving {
                entry action assignRelieving { position := ValvePosition::fullyOpen; }
                do action dischargeFluid {
                    out flowRate = body.ratedCapacity;
                }
            }

            transition relievingToClosing
                first relieving
                accept pressureDrop : ISQ::PressureValue
                if pressureDrop <= blowdownPressure
                then closing;

            state closing {
                entry action assignClosing { position := ValvePosition::closing; }
                do action actuateClose {
                    out liftDistance = 0.0 [SI::mm];
                }
            }

            transition closingToSeated
                first closing
                accept fullySeated : Boolean
                if fullySeated
                then seated;
        }
    }

    part def ProtectedVessel {
        attribute internalPressure : PressureValue;
        attribute maxAllowableWorkingPressure : PressureValue;
        attribute volume : VolumeValue;
        port vesselPort : PressurePort;
    }

    part def DischargeSystem {
        attribute dischargeCapacity : VolumeFlowRateValue;
        attribute backPressure : PressureValue;
        port dischargePort : FlowPort;
    }

    part safetyValveSystem {
        doc /* 
         * A safety valve system designed to automatically relieve excess pressure
         * from a protected vessel to prevent catastrophic failure. The system
         * continuously monitors vessel pressure and opens when the set pressure
         * is reached, discharging fluid to a safe location until pressure drops
         * to the blowdown level, at which point it automatically reseats.
         */

        attribute systemSetPressure : PressureValue = 1000.0 [SI::kPa];
        attribute systemBlowdown : PressureValue = 900.0 [SI::kPa];

        part vessel : ProtectedVessel {
            attribute :>> maxAllowableWorkingPressure : PressureValue = 950.0 [SI::kPa];
            attribute :>> volume : VolumeValue = 10.0 [SI::'m^3'];
        }

        part valve : SafetyValve {
            attribute :>> setPressure : PressureValue = systemSetPressure;
            attribute :>> blowdownPressure : PressureValue = systemBlowdown;
            attribute :>> relievingCapacity : VolumeFlowRateValue = 500.0 [SI::'m^3'/SI::h];

            part :>> sensor {
                attribute :>> accuracy = 0.5;
            }

            part :>> spring {
                attribute :>> springConstant : Real = 50000.0;
                attribute :>> preloadForce : ForceValue = 5000.0 [SI::N];
            }

            part :>> disc {
                attribute :>> seatDiameter : LengthValue = 50.0 [SI::mm];
                attribute :>> liftHeight : LengthValue = 10.0 [SI::mm];
            }

            part :>> body {
                attribute :>> inletDiameter : LengthValue = 80.0 [SI::mm];
                attribute :>> outletDiameter : LengthValue = 100.0 [SI::mm];
                attribute :>> ratedCapacity : VolumeFlowRateValue = 500.0 [SI::'m^3'/SI::h];
            }
        }

        part discharge : DischargeSystem {
            attribute :>> dischargeCapacity : VolumeFlowRateValue = 600.0 [SI::'m^3'/SI::h];
            attribute :>> backPressure : PressureValue = 101.325 [SI::kPa];
        }

        connection vesselToValve connect vessel.vesselPort to valve.body.inlet;
        connection valveToDischarge connect valve.body.outlet to discharge.dischargePort;

        assert constraint pressureBalance {
            vessel.internalPressure == valve.operatingPressure
        }
    }

    requirement <'REQ-SV-001'> primarySafetyFunction {
        doc /* 
         * The safety valve system shall automatically relieve excess pressure
         * from the protected vessel when pressure exceeds the set pressure,
         * preventing catastrophic overpressure failure and protecting personnel,
         * equipment, and the environment.
         */
        subject system :> safetyValveSystem;
    }

    requirement <'REQ-SV-002'> continuousPressureMonitoring {
        doc /* 
         * The safety valve shall continuously monitor the pressure in the
         * protected vessel through its integrated pressure sensing mechanism.
         */
        subject valve :> safetyValveSystem.valve;

        require constraint {
            valve.sensor.measuredPressure == valve.operatingPressure
        }
    }

    requirement <'REQ-SV-003'> automaticActivation {
        doc /* 
         * The safety valve shall automatically open when the vessel pressure
         * reaches or exceeds the set pressure value.
         */
        subject valve :> safetyValveSystem.valve;

        assert constraint {
            valve.operatingPressure >= valve.setPressure implies
            (valve.position == ValvePosition::opening or valve.position == ValvePosition::fullyOpen)
        }
    }

    requirement <'REQ-SV-004'> adequateRelievingCapacity {
        doc /* 
         * The safety valve shall have sufficient relieving capacity to discharge
         * fluid faster than pressure can build up in the protected vessel.
         */
        subject valve :> safetyValveSystem.valve;

        assert constraint {
            valve.relievingCapacity >= valve.body.ratedCapacity
        }
    }

    requirement <'REQ-SV-005'> vesselProtection {
        doc /* 
         * The safety valve set pressure shall be at or below the maximum
         * allowable working pressure of the protected vessel.
         */
        subject system :> safetyValveSystem;

        assert constraint {
            system.valve.setPressure <= system.vessel.maxAllowableWorkingPressure
        }
    }

    requirement <'REQ-SV-006'> automaticReseating {
        doc /* 
         * The safety valve shall automatically close and reseat when the
         * vessel pressure drops to the blowdown pressure level.
         */
        subject valve :> safetyValveSystem.valve;

        assert constraint {
            valve.operatingPressure <= valve.blowdownPressure implies
            (valve.position == ValvePosition::closing or valve.position == ValvePosition::fullyClosed)
        }
    }

    requirement <'REQ-SV-007'> dischargeCapacity {
        doc /* 
         * The discharge system shall have capacity equal to or greater than
         * the maximum relieving capacity of the safety valve.
         */
        subject discharge :> safetyValveSystem.discharge;

        assert constraint {
            discharge.dischargeCapacity >= safetyValveSystem.valve.relievingCapacity
        }
    }

    satisfy primarySafetyFunction by safetyValveSystem;
    satisfy continuousPressureMonitoring by safetyValveSystem.valve;
    satisfy automaticActivation by safetyValveSystem.valve;
    satisfy adequateRelievingCapacity by safetyValveSystem.valve;
    satisfy vesselProtection by safetyValveSystem;
    satisfy automaticReseating by safetyValveSystem.valve;
    satisfy dischargeCapacity by safetyValveSystem.discharge;
}
