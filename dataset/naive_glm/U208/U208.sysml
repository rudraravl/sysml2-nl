package InfusionPumpSystem {
    import ScalarValues::*;
    import Quantities::*;
    import MeasurementReferences::*;

    // --- Items ---
    item def LiquidMedication;

    // --- Units ---
    item def Milliliter :> MeasurementReferences::Unit;
    item def MilliliterPerHour :> MeasurementReferences::Unit;
    item def Kilopascal :> MeasurementReferences::Unit;
    item def RevolutionsPerMinute :> MeasurementReferences::Unit;

    // --- Value Types ---
    attribute def Volume :> Quantities::QuantityValue {
        redefines mref : Milliliter;
    }
    attribute def FlowRate :> Quantities::QuantityValue {
        redefines mref : MilliliterPerHour;
    }
    attribute def Pressure :> Quantities::QuantityValue {
        redefines mref : Kilopascal;
    }
    attribute def RotationalSpeed :> Quantities::QuantityValue {
        redefines mref : RevolutionsPerMinute;
    }

    // --- Ports ---
    port def FluidInPort {
        in med : LiquidMedication;
    }
    port def FluidOutPort {
        out med : LiquidMedication;
    }
    port def FlowSignalInPort {
        in flowRate : FlowRate;
    }
    port def FlowSignalOutPort {
        out flowRate : FlowRate;
    }
    port def PressureSignalInPort {
        in pressure : Pressure;
    }
    port def PressureSignalOutPort {
        out pressure : Pressure;
    }
    port def PumpControlInPort {
        in pumpSpeed : RotationalSpeed;
    }
    port def PumpControlOutPort {
        out pumpSpeed : RotationalSpeed;
    }
    port def PowerInPort {
        in voltage : Real;
    }
    port def PowerOutPort {
        out voltage : Real;
    }

    // --- Requirements ---
    requirement def MedicationDeliveryRequirement {
        doc /* The system shall deliver the precise amount of medication at a controlled rate. */
    }
    requirement def SafetyHaltRequirement {
        doc /* The system shall halt the pump if pressure exceeds the maximum safe limit. */
    }
    requirement def DoseCompletionRequirement {
        doc /* The system shall automatically stop once the total prescribed dose has been delivered. */
    }

    // --- Part Definitions ---
    part def Battery {
        out pwrOut : PowerOutPort;
        attribute chargeLevel : Real = 100;
    }

    part def DrugReservoir {
        out fluidOut : FluidOutPort;
        attribute currentVolume : Volume;
    }

    part def PumpMechanism {
        in fluidIn : FluidInPort;
        out fluidOut : FluidOutPort;
        in control : PumpControlInPort;
        attribute currentSpeed : RotationalSpeed;
    }

    part def FlowSensor {
        in fluidIn : FluidInPort;
        out fluidOut : FluidOutPort;
        out flowSignal : FlowSignalOutPort;
    }

    part def PressureSensor {
        in fluidIn : FluidInPort;
        out fluidOut : FluidOutPort;
        out pressureSignal : PressureSignalOutPort;
    }

    part def DeliveryCatheter {
        in fluidIn : FluidInPort;
    }

    part def ControlUnit {
        in flowFeedback : FlowSignalInPort;
        in pressureFeedback : PressureSignalInPort;
        out pumpControl : PumpControlOutPort;
        in pwr : PowerInPort;

        attribute targetDose : Volume;
        attribute targetRate : FlowRate;
        attribute maxSafePressure : Pressure;
        attribute deliveredVolume : Volume;

        satisfy SafetyHaltRequirement;
        satisfy DoseCompletionRequirement;

        state ControlBehavior {
            transition init from initial to Off;
            state Off;
            state Idle;
            state Infusing;
            state Alarm;
            state Complete;

            transition powerOn from Off to Idle when pwr.voltage > 0.0;
            transition start from Idle to Infusing;

            transition halt from Infusing to Alarm when pressureFeedback.pressure.num > maxSafePressure.num {
                pumpControl.pumpSpeed.num = 0.0;
            }

            transition finish from Infusing to Complete when deliveredVolume.num >= targetDose.num {
                pumpControl.pumpSpeed.num = 0.0;
            }

            transition resetAlarm from Alarm to Idle;
            transition resetComplete from Complete to Idle;

            state Infusing {
                do {
                    deliveredVolume.num = deliveredVolume.num + flowFeedback.flowRate.num;
                    pumpControl.pumpSpeed.num = targetRate.num;
                }
            }
        }
    }

    // --- System Definition ---
    part def InfusionPump {
        satisfy MedicationDeliveryRequirement;

        part battery : Battery;
        part reservoir : DrugReservoir;
        part pump : PumpMechanism;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part catheter : DeliveryCatheter;
        part controller : ControlUnit;

        // Fluid connections
        connect reservoir.fluidOut to pump.fluidIn;
        connect pump.fluidOut to flowSensor.fluidIn;
        connect flowSensor.fluidOut to pressureSensor.fluidIn;
        connect pressureSensor.fluidOut to catheter.fluidIn;

        // Signal and control connections
        connect flowSensor.flowSignal to controller.flowFeedback;
        connect pressureSensor.pressureSignal to controller.pressureFeedback;
        connect controller.pumpControl to pump.control;

        // Power connections
        connect battery.pwrOut to controller.pwr;
    }
}
