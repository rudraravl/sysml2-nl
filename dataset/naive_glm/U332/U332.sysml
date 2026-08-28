package OdonDevice {
    import ScalarValues::*;

    // ===== Units =====
    unit kPa;
    unit N;
    unit deg;
    unit mL;
    unit s;
    unit mm;
    unit g;

    // ===== Value Definitions =====
    value def PressureValue :> Real {
        doc "Air pressure inside the inflatable sleeve";
        unit kPa;
    }
    value def ForceValue :> Real {
        doc "Traction force applied to baby's head";
        unit N;
    }
    value def AngleValue :> Real {
        doc "Angle of applied traction relative to axis";
        unit deg;
    }
    value def VolumeValue :> Real {
        doc "Inflated volume of the sleeve";
        unit mL;
    }
    value def DurationValue :> Real {
        doc "Elapsed time or duration";
        unit s;
    }
    value def LengthValue :> Real {
        doc "Linear dimension";
        unit mm;
    }
    value def MassValue :> Real {
        doc "Mass";
        unit g;
    }

    // ===== Item Definitions =====
    item def Air {
        doc "Compressed air for sleeve inflation";
    }
    item def ControlCommand {
        attribute commandType : String;
        attribute targetPressure : PressureValue;
        attribute targetForce : ForceValue;
        attribute targetAngle : AngleValue;
    }
    item def SensorData {
        attribute pressure : PressureValue;
        attribute force : ForceValue;
        attribute angle : AngleValue;
        attribute timestamp : DurationValue;
    }
    item def AlarmEvent {
        attribute alarmType : String;
        attribute severity : String;
        attribute message : String;
    }

    // ===== Port Definitions =====
    port def AirSupplyPort {
        out item air : Air;
    }
    port def AirDemandPort {
        in item air : Air;
    }
    port def PressurePort {
        out attribute pressure : PressureValue;
    }
    port def ForcePort {
        out attribute force : ForceValue;
    }
    port def AnglePort {
        out attribute angle : AngleValue;
    }
    port def DataOutPort {
        out attribute data : SensorData;
    }
    port def ControlOutPort {
        out attribute command : ControlCommand;
    }
    port def ControlInPort {
        in attribute command : ControlCommand;
    }
    port def AlarmOutPort {
        out attribute alarm : AlarmEvent;
    }

    // ===== Component Definitions =====

    part def ApplicatorCup {
        doc "Rigid, cup-shaped applicator made of medical-grade plastic, placed over the baby's head during second stage of labor";
        attribute material : String = "Medical-grade Polycarbonate";
        attribute innerDiameter : LengthValue = 100.0;
        attribute depth : LengthValue = 80.0;
        attribute wallThickness : LengthValue = 2.0;
        attribute isSterile : Boolean = true;
        attribute isReusable : Boolean = false;
        attribute maxBabyHeadCircumference : LengthValue = 350.0;
        port sleeveMount : AirDemandPort;
    }

    part def InflatableSleeve {
        doc "Soft, inflatable sleeve housed inside the applicator cup, creates a gentle and secure grip around the baby's head without causing trauma";
        attribute material : String = "Medical-grade Silicone";
        attribute maxVolume : VolumeValue = 50.0;
        attribute currentVolume : VolumeValue = 0.0;
        attribute currentPressure : PressureValue = 0.0;
        attribute isSterile : Boolean = true;
        attribute targetGripPressure : PressureValue = 40.0;
        port airInlet : AirDemandPort;
        port pressureOut : PressurePort;
    }

    part def AirPump {
        doc "External air pump that supplies air to inflate the sleeve";
        attribute maxOutputPressure : PressureValue = 80.0;
        attribute maxFlowRate : VolumeValue = 10.0;
        attribute isRunning : Boolean = false;
        attribute powerLevel : Real = 0.0;
        port airOutput : AirSupplyPort;
        port controlIn : ControlInPort;
    }

    part def PressureRegulator {
        doc "Pressure regulator that manages the air pressure supplied to the sleeve, ensuring controlled inflation";
        attribute setPoint : PressureValue = 40.0;
        attribute regulatedPressure : PressureValue = 0.0;
        attribute tolerance : PressureValue = 2.0;
        port airInput : AirDemandPort;
        port airOutput : AirSupplyPort;
        port controlIn : ControlInPort;
    }

    part def SafetyValve {
        doc "Critical safety valve integrated into the air system to automatically vent excess pressure, preventing over-inflation";
        attribute thresholdPressure : PressureValue = 55.0;
        attribute resetThreshold : PressureValue = 50.0;
        attribute isOpen : Boolean = false;
        attribute ventRate : VolumeValue = 20.0;
        port airInput : AirDemandPort;
        port airOutput : AirSupplyPort;
        port ventPort : AirSupplyPort;
        port controlIn : ControlInPort;
    }

    part def TractionHandle {
        doc "Attached traction handle used by a medical professional to apply gentle pulling force at a controlled angle";
        attribute material : String = "Medical-grade Stainless Steel";
        attribute maxAngle : AngleValue = 45.0;
        attribute currentAngle : AngleValue = 0.0;
        attribute appliedForce : ForceValue = 0.0;
        attribute handleLength : LengthValue = 150.0;
        port forceOut : ForcePort;
        port angleOut : AnglePort;
    }

    part def PressureSensor {
        doc "Sensor that continuously monitors pressure within the inflatable sleeve";
        attribute range : PressureValue = 100.0;
        attribute accuracy : PressureValue = 0.5;
        attribute samplingRate : Real = 10.0;
        attribute isCalibrated : Boolean = true;
        port measurementIn : PressurePort;
        port dataOut : DataOutPort;
    }

    part def ForceSensor {
        doc "Sensor that continuously monitors the amount of traction force being applied";
        attribute range : ForceValue = 100.0;
        attribute accuracy : ForceValue = 1.0;
        attribute samplingRate : Real = 100.0;
        attribute isCalibrated : Boolean = true;
        port forceIn : ForcePort;
        port angleIn : AnglePort;
        port dataOut : DataOutPort;
    }

    part def DisplayUnit {
        doc "Display unit for showing pressure, force, angle, and system status to the medical professional";
        attribute isActive : Boolean = true;
        attribute backlightLevel : Real = 0.8;
        port alarmIn : AlarmOutPort;
        port pressureDisplayIn : DataOutPort;
        port forceDisplayIn : DataOutPort;
    }

    part def ControlUnit {
        doc "Control unit that ensures all actions remain within strict, predefined safety limits for pressure and force, protecting both mother and baby";
        attribute maxSafePressure : PressureValue = 50.0;
        attribute minGripPressure : PressureValue = 30.0;
        attribute maxTractionForce : ForceValue = 50.0;
        attribute maxProcedureTime : DurationValue = 600.0;
        attribute currentPressure : PressureValue = 0.0;
        attribute currentForce : ForceValue = 0.0;
        attribute currentAngle : AngleValue = 0.0;
        attribute elapsedTime : DurationValue = 0.0;
        attribute alarmActive : Boolean = false;
        attribute procedureComplete : Boolean = false;

        port pressureIn : DataOutPort;
        port forceIn : DataOutPort;
        port pumpControl : ControlOutPort;
        port regulatorControl : ControlOutPort;
        port valveControl : ControlOutPort;
        port alarmOut : AlarmOutPort;

        exhibit state OdonControlStateMachine {
            doc "Operational state machine governing the Odon device procedure from idle through delivery and removal";

            state idle {
                doc "Device is powered on, calibrated, and ready but not in use";
            }
            state positioning {
                doc "Applicator cup is being carefully placed over the baby's head by the medical professional";
            }
            state inflating {
                doc "Air pump supplies air through the pressure regulator to inflate the sleeve";
            }
            state gripping {
                doc "Sleeve has inflated to target pressure, creating a soft and secure grip around the baby's head";
            }
            state applyingTraction {
                doc "Medical professional applies gentle pulling force at a controlled angle via the traction handle";
            }
            state deflating {
                doc "Sleeve is being deflated to release grip after delivery is complete";
            }
            state removed {
                doc "Device has been removed from the patient and is ready for disposal or reset";
            }
            state emergencyVenting {
                doc "Emergency state triggered by over-pressure or over-force; safety valve opens automatically";
            }

            transition from idle to positioning when startCommand;
            transition from positioning to inflating when positionConfirmed;
            transition from inflating to gripping when currentPressure >= minGripPressure;
            transition from gripping to applyingTraction when gripConfirmed;
            transition from applyingTraction to deflating when deliveryComplete;
            transition from deflating to removed when currentPressure <= 0.0;
            transition from removed to idle when resetCommand;

            transition from inflating to emergencyVenting when currentPressure > maxSafePressure;
            transition from gripping to emergencyVenting when currentPressure > maxSafePressure;
            transition from applyingTraction to emergencyVenting when currentForce > maxTractionForce;
            transition from applyingTraction to emergencyVenting when currentAngle > 45.0;
            transition from emergencyVenting to deflating when currentPressure <= maxSafePressure;
        }
    }

    // ===== Requirements =====

    requirement def PressureSafetyRequirement {
        doc "The system shall prevent the sleeve pressure from exceeding 50 kPa to protect the baby's head from trauma";
        subject system : OdonDevice;
        attribute maxPressure : PressureValue = 50.0;
        assert system.controlUnit.maxSafePressure <= maxPressure;
    }

    requirement def ForceSafetyRequirement {
        doc "The system shall prevent the traction force from exceeding 50 N to protect both mother and baby";
        subject system : OdonDevice;
        attribute maxForce : ForceValue = 50.0;
        assert system.controlUnit.maxTractionForce <= maxForce;
    }

    requirement def EmergencyVentRequirement {
        doc "The safety valve shall automatically vent excess pressure when pressure exceeds 55 kPa without requiring operator intervention";
        subject system : OdonDevice;
        attribute ventThreshold : PressureValue = 55.0;
        assert system.safetyValve.thresholdPressure <= ventThreshold;
    }

    requirement def ProcedureTimeRequirement {
        doc "The entire procedure shall be completed within 600 seconds to minimize stress on mother and baby";
        subject system : OdonDevice;
        attribute maxTime : DurationValue = 600.0;
        assert system.controlUnit.maxProcedureTime <= maxTime;
    }

    requirement def SterilityRequirement {
        doc "All patient-contacting components shall be sterile and single-use to prevent infection";
        subject system : OdonDevice;
        assert system.applicatorCup.isSterile == true;
        assert system.inflatableSleeve.isSterile == true;
        assert system.applicatorCup.isReusable == false;
    }

    requirement def TractionAngleRequirement {
        doc "Traction shall be applied at a controlled angle not exceeding 45 degrees to ensure safe force delivery";
        subject system : OdonDevice;
        attribute maxAngle : AngleValue = 45.0;
        assert system.tractionHandle.maxAngle <= maxAngle;
    }

    requirement def GentleGripRequirement {
        doc "The inflatable sleeve shall create a soft and secure grip without causing trauma, using medical-grade silicone at a minimum grip pressure of 30 kPa";
        subject system : OdonDevice;
        attribute minGrip : PressureValue = 30.0;
        assert system.controlUnit.minGripPressure >= 20.0;
    }

    requirement def ContinuousMonitoringRequirement {
        doc "The system shall continuously monitor both pressure and traction force throughout the entire procedure";
        subject system : OdonDevice;
        assert system.pressureSensor.samplingRate > 0.0;
        assert system.forceSensor.samplingRate > 0.0;
    }

    requirement def ControlledInflationRequirement {
        doc "The pressure regulator shall manage inflation to a set point of 40 kPa with a tolerance of 2 kPa";
        subject system : OdonDevice;
        assert system.pressureRegulator.setPoint == 40.0;
        assert system.pressureRegulator.tolerance <= 2.0;
    }

    // ===== The Odon Device System =====

    part def OdonDevice {
        doc "Odon Device — a medical system designed to assist in vaginal childbirth during the second stage of labor by applying gentle, controlled traction to the baby's head";

        part applicatorCup : ApplicatorCup;
        part inflatableSleeve : InflatableSleeve;
        part airPump : AirPump;
        part pressureRegulator : PressureRegulator;
        part safetyValve : SafetyValve;
        part tractionHandle : TractionHandle;
        part pressureSensor : PressureSensor;
        part forceSensor : ForceSensor;
        part controlUnit : ControlUnit;
        part displayUnit : DisplayUnit;

        // Air supply chain: pump -> regulator -> safety valve -> sleeve
        connection airPumpToRegulator connect airPump.airOutput to pressureRegulator.airInput;
        connection regulatorToValve connect pressureRegulator.airOutput to safetyValve.airInput;
        connection valveToSleeve connect safetyValve.airOutput to inflatableSleeve.airInlet;

        // Sleeve mounts inside applicator cup
        connection sleeveInCup connect inflatableSleeve.airInlet to applicatorCup.sleeveMount;

        // Pressure measurement from sleeve to pressure sensor
        connection sleevePressureToSensor connect inflatableSleeve.pressureOut to pressureSensor.measurementIn;

        // Force and angle measurement from handle to force sensor
        connection handleForceToSensor connect tractionHandle.forceOut to forceSensor.forceIn;
        connection handleAngleToSensor connect tractionHandle.angleOut to forceSensor.angleIn;

        // Sensor data to control unit
        connection pressureDataToControl connect pressureSensor.dataOut to controlUnit.pressureIn;
        connection forceDataToControl connect forceSensor.dataOut to controlUnit.forceIn;

        // Control signals from control unit to actuators
        connection pumpControlSignal connect controlUnit.pumpControl to airPump.controlIn;
        connection regulatorControlSignal connect controlUnit.regulatorControl to pressureRegulator.controlIn;
        connection valveControlSignal connect controlUnit.valveControl to safetyValve.controlIn;

        // Alarm and display data
        connection alarmToDisplay connect controlUnit.alarmOut to displayUnit.alarmIn;
        connection pressureDataToDisplay connect pressureSensor.dataOut to displayUnit.pressureDisplayIn;
        connection forceDataToDisplay connect forceSensor.dataOut to displayUnit.forceDisplayIn;

        // Requirement satisfaction
        satisfy PressureSafetyRequirement;
        satisfy ForceSafetyRequirement;
        satisfy EmergencyVentRequirement;
        satisfy ProcedureTimeRequirement;
        satisfy SterilityRequirement;
        satisfy TractionAngleRequirement;
        satisfy GentleGripRequirement;
        satisfy ContinuousMonitoringRequirement;
        satisfy ControlledInflationRequirement;
    }
}
