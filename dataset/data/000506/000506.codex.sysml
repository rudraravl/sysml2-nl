package SubstanceBasedMedicalDevice {

    import ScalarValues::*;

    attribute def Volume_mL : Real;
    attribute def FlowRate_mL_per_h : Real;
    attribute def Dose_U : Real;
    attribute def Concentration_U_per_mL : Real;
    attribute def Pressure_kPa : Real;
    attribute def Time_s : Real;
    attribute def Temperature_C : Real;
    attribute def BatteryEnergy_mWh : Real;
    attribute def Percent : Real;

    item def InsulinSolution {
        attribute concentration : Concentration_U_per_mL = 100.0;
        attribute volume : Volume_mL;
        attribute temperature : Temperature_C;
    }

    item def DoseCommand {
        attribute requestedDose : Dose_U;
        attribute maxDose : Dose_U;
        attribute requestedFlowRate : FlowRate_mL_per_h;
    }

    item def DeliveryRecord {
        attribute deliveredDose : Dose_U;
        attribute deliveredVolume : Volume_mL;
        attribute deliveryDuration : Time_s;
        attribute completed : Boolean;
    }

    item def OcclusionStatus {
        attribute linePressure : Pressure_kPa;
        attribute occlusionDetected : Boolean;
    }

    item def BatteryStatus {
        attribute stateOfCharge : Percent;
        attribute remainingEnergy : BatteryEnergy_mWh;
    }

    port def FluidInPort {
        in item fluid : InsulinSolution;
    }

    port def FluidOutPort {
        out item fluid : InsulinSolution;
    }

    port def CommandInPort {
        in item command : DoseCommand;
    }

    port def RecordOutPort {
        out item record : DeliveryRecord;
    }

    port def StatusOutPort {
        out item occlusion : OcclusionStatus;
        out item battery : BatteryStatus;
    }

    part def DrugReservoir {
        attribute nominalVolume : Volume_mL = 3.0;
        attribute remainingVolume : Volume_mL;
        attribute insulinConcentration : Concentration_U_per_mL = 100.0;

        port outlet : FluidOutPort;
    }

    part def MicroPump {
        attribute minimumFlowRate : FlowRate_mL_per_h = 0.01;
        attribute maximumFlowRate : FlowRate_mL_per_h = 1.20;
        attribute commandedFlowRate : FlowRate_mL_per_h;
        attribute cumulativeDeliveredVolume : Volume_mL;

        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        port commandIn : CommandInPort;
    }

    part def InfusionSet {
        attribute cannulaPrimeVolume : Volume_mL = 0.08;
        attribute maximumAllowedPressure : Pressure_kPa = 250.0;

        port inlet : FluidInPort;
        port patientInterface : FluidOutPort;
    }

    part def PressureSensor {
        attribute measuredPressure : Pressure_kPa;
        attribute occlusionThreshold : Pressure_kPa = 250.0;

        port statusOut : StatusOutPort;
    }

    part def Controller {
        attribute basalRate : FlowRate_mL_per_h = 0.05;
        attribute dailyDoseLimit : Dose_U = 80.0;
        attribute singleBolusLimit : Dose_U = 15.0;
        attribute activeDoseCommanded : Dose_U;

        port doseCommandIn : CommandInPort;
        port pumpCommandOut : CommandInPort;
        port recordOut : RecordOutPort;
        port statusOut : StatusOutPort;
    }

    part def Battery {
        attribute capacity : BatteryEnergy_mWh = 900.0;
        attribute remainingEnergy : BatteryEnergy_mWh;
        attribute lowBatteryThreshold : Percent = 15.0;

        port statusOut : StatusOutPort;
    }

    part def UserInterface {
        attribute bolusIncrement : Dose_U = 0.1;

        port commandOut : CommandInPort;
        port recordIn : RecordOutPort;
        port statusIn : StatusOutPort;
    }

    part def WearableInsulinInfusionDevice {
        attribute deviceMass_g : Real = 42.0;
        attribute intendedWearTime_h : Real = 72.0;
        attribute operatingTemperatureMin : Temperature_C = 5.0;
        attribute operatingTemperatureMax : Temperature_C = 40.0;

        part reservoir : DrugReservoir;
        part pump : MicroPump;
        part infusionSet : InfusionSet;
        part controller : Controller;
        part pressureSensor : PressureSensor;
        part battery : Battery;
        part userInterface : UserInterface;

        port doseCommandIn : CommandInPort;
        port therapyRecordOut : RecordOutPort;
        port deviceStatusOut : StatusOutPort;

        connect reservoir.outlet to pump.inlet;
        connect pump.outlet to infusionSet.inlet;
        connect userInterface.commandOut to controller.doseCommandIn;
        connect controller.pumpCommandOut to pump.commandIn;
        connect controller.recordOut to userInterface.recordIn;
        connect pressureSensor.statusOut to controller.statusOut;
        connect battery.statusOut to controller.statusOut;
        connect doseCommandIn to controller.doseCommandIn;
        connect controller.recordOut to therapyRecordOut;
        connect controller.statusOut to deviceStatusOut;
    }

    action def ValidateDoseCommand {
        in command : DoseCommand;
        in singleBolusLimit : Dose_U;
        in dailyDoseLimit : Dose_U;
        out accepted : Boolean;

        constraint doseMustBePositive {
            command.requestedDose > 0.0
        }

        constraint doseMustNotExceedSingleLimit {
            command.requestedDose <= singleBolusLimit
        }

        constraint doseMustNotExceedDailyLimit {
            command.requestedDose <= dailyDoseLimit
        }
    }

    action def PrimeInfusionPath {
        in primeVolume : Volume_mL;
        out primingComplete : Boolean;
    }

    action def DeliverInsulinDose {
        in command : DoseCommand;
        in concentration : Concentration_U_per_mL;
        out record : DeliveryRecord;

        attribute targetVolume : Volume_mL;

        constraint calculateTargetVolume {
            targetVolume == command.requestedDose / concentration
        }
    }

    action def MonitorDeliveryPressure {
        in measuredPressure : Pressure_kPa;
        in occlusionThreshold : Pressure_kPa;
        out status : OcclusionStatus;

        constraint detectOcclusion {
            status.occlusionDetected == (measuredPressure >= occlusionThreshold)
        }
    }

    action def StopFluidDelivery {
        out stopped : Boolean;
    }

    action def ReportTherapyRecord {
        in record : DeliveryRecord;
        out transmitted : Boolean;
    }

    state def TherapyControlStateMachine {
        state Off;
        state SelfTest;
        state Ready;
        state Priming;
        state DeliveringBasal;
        state DeliveringBolus;
        state Suspended;
        state Alarm;

        transition InitialPowerOn
            first Off
            then SelfTest;

        transition SelfTestPassed
            first SelfTest
            then Ready;

        transition PrimeRequested
            first Ready
            then Priming
            effect PrimeInfusionPath;

        transition PrimingComplete
            first Priming
            then DeliveringBasal;

        transition BolusAccepted
            first DeliveringBasal
            then DeliveringBolus
            effect ValidateDoseCommand;

        transition BolusComplete
            first DeliveringBolus
            then DeliveringBasal
            effect ReportTherapyRecord;

        transition UserSuspend
            first DeliveringBasal
            then Suspended
            effect StopFluidDelivery;

        transition ResumeTherapy
            first Suspended
            then DeliveringBasal;

        transition OcclusionAlarm
            first DeliveringBasal
            then Alarm
            effect StopFluidDelivery;

        transition BolusOcclusionAlarm
            first DeliveringBolus
            then Alarm
            effect StopFluidDelivery;

        transition LowBatteryAlarm
            first DeliveringBasal
            then Alarm
            effect StopFluidDelivery;

        transition AlarmCleared
            first Alarm
            then Ready;
    }

    requirement def PrimaryFunctionRequirement {
        subject device : WearableInsulinInfusionDevice;

        doc
        /* The device shall store a sterile insulin substance and deliver programmed basal and bolus quantities through a controlled infusion path into subcutaneous tissue to support glucose management. */

        require constraint {
            device.reservoir.insulinConcentration == 100.0
        }
    }

    requirement def DoseAccuracyRequirement {
        subject device : WearableInsulinInfusionDevice;

        attribute allowableDoseErrorPercent : Percent = 5.0;

        require constraint {
            device.controller.singleBolusLimit <= 15.0
        }
    }

    requirement def OcclusionProtectionRequirement {
        subject device : WearableInsulinInfusionDevice;

        require constraint {
            device.infusionSet.maximumAllowedPressure <= 250.0
        }
    }

    requirement def ReservoirCapacityRequirement {
        subject device : WearableInsulinInfusionDevice;

        require constraint {
            device.reservoir.nominalVolume >= 3.0
        }
    }

    requirement def WearTimeRequirement {
        subject device : WearableInsulinInfusionDevice;

        require constraint {
            device.intendedWearTime_h >= 72.0
        }
    }

    requirement def BatteryRequirement {
        subject device : WearableInsulinInfusionDevice;

        require constraint {
            device.battery.capacity >= 900.0
        }
    }

    requirement def OperatingTemperatureRequirement {
        subject device : WearableInsulinInfusionDevice;

        require constraint {
            device.operatingTemperatureMin <= 5.0 and device.operatingTemperatureMax >= 40.0
        }
    }

    part wearablePatch : WearableInsulinInfusionDevice;

}