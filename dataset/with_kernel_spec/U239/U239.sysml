package MedicalIllumination_Base {
    private import ScalarValues::*;

    attribute def Temperature :> Real;
    attribute def Percent :> Real;
    attribute def IntensityLevel :> Integer;
    attribute def ColorTemp :> Integer;
    attribute def Length :> Real;
    attribute def Duration :> Real;
    attribute def LuminousFlux :> Real;

    item def LightFlow;
    item def PowerFlow;
    item def ControlSignal;
    item def StatusSignal;

    part def LEDIlluminationModule {
        attribute colorTemp : ColorTemp = 5500;
        attribute maxFlux : LuminousFlux = 1000;
        port powerIn { in item : PowerFlow; }
        port lightOut { out item : LightFlow; }
    }

    part def FiberOpticGuide {
        attribute length : Length = 1.5;
        port lightIn { in item : LightFlow; }
        port lightOut { out item : LightFlow; }
    }

    part def OpticalHeadpiece {
        attribute beamAdjustment : IntensityLevel;
        port lightIn { in item : LightFlow; }
        port focusedLightOut { out item : LightFlow; }
    }

    part def BatteryPack {
        attribute charge : Percent = 100;
        attribute operatingTime : Duration = 4.5;
        port powerOut { out item : PowerFlow; }
        port statusOut { out item : StatusSignal; }
    }

    part def UserInterface {
        attribute currentIntensity : IntensityLevel = 5;
        port statusIn { in item : StatusSignal; }
        port commandOut { out item : ControlSignal; }
    }

    part def TemperatureSensor {
        port tempOut { out item : StatusSignal; }
    }

    part def PowerManagementUnit {
        port powerIn { in item : PowerFlow; }
        port commandIn { in item : ControlSignal; }
        port powerOut { out item : PowerFlow; }
        port statusOut { out item : StatusSignal; }
        port tempIn { in item : StatusSignal; }
        port batteryIn { in item : StatusSignal; }

        attribute temperature : Temperature = 25;
        attribute batteryCharge : Percent = 100;
        attribute currentIntensity : IntensityLevel = 5;

        state machine def ManagementState {
            state operational;
            state conservation;
            state shutdown;

            transition operational_to_conservation
                first operational
                then conservation
                if (batteryCharge < 20 or temperature > 70);

            transition conservation_to_shutdown
                first conservation
                then shutdown
                if (batteryCharge < 5 or temperature > 85);

            transition conservation_to_operational
                first conservation
                then operational
                if (batteryCharge > 30 and temperature < 60);
        }
    }

    part def MedicalIlluminationSystem {
        part led : LEDIlluminationModule;
        part fiber : FiberOpticGuide;
        part headpiece : OpticalHeadpiece;
        part battery : BatteryPack;
        part ui : UserInterface;
        part pmu : PowerManagementUnit;
        part tempSensor : TemperatureSensor;

        connect battery.powerOut to pmu.powerIn;
        connect pmu.powerOut to led.powerIn;
        connect led.lightOut to fiber.lightIn;
        connect fiber.lightOut to headpiece.lightIn;
        connect ui.commandOut to pmu.commandIn;
        connect pmu.statusOut to ui.statusIn;
        connect battery.statusOut to pmu.batteryIn;
        connect tempSensor.tempOut to pmu.tempIn;
    }
}

package MedicalIllumination_Requirements {
    import MedicalIllumination_Base::**;

    requirement <'REQ-1'> longOperation {
        doc /* The system shall operate for over 4 hours on a single charge. */
        subject system : MedicalIlluminationSystem;
        assert constraint {
            system.battery.operatingTime > 4
        }
    }

    requirement <'REQ-2'> tissueColor {
        doc /* The LED shall provide a color temperature of 5500K for accurate tissue representation. */
        subject led : LEDIlluminationModule;
        assert constraint {
            led.colorTemp == 5500
        }
    }

    requirement <'REQ-3'> thermalSafety {
        doc /* The light source shall be separated from the user via a 1.5m fiber optic guide. */
        subject fiber : FiberOpticGuide;
        assert constraint {
            fiber.length == 1.5
        }
    }

    requirement <'REQ-4'> lowBatteryManagement {
        doc /* The system shall reduce intensity and provide warning if battery charge is low. */
        subject pmu : PowerManagementUnit;
    }

    requirement <'REQ-5'> overheatProtection {
        doc /* The system shall reduce intensity or shutdown if internal temperature is too high. */
        subject pmu : PowerManagementUnit;
    }
}

package MedicalIllumination_Architecture {
    import MedicalIllumination_Base::**;
    import MedicalIllumination_Requirements::**;

    part medicalIlluminationSystem : MedicalIlluminationSystem;

    satisfy MedicalIllumination_Requirements::longOperation by medicalIlluminationSystem;
    satisfy MedicalIllumination_Requirements::tissueColor by medicalIlluminationSystem.led;
    satisfy MedicalIllumination_Requirements::thermalSafety by medicalIlluminationSystem.fiber;
    satisfy MedicalIllumination_Requirements::lowBatteryManagement by medicalIlluminationSystem.pmu;
    satisfy MedicalIllumination_Requirements::overheatProtection by medicalIlluminationSystem.pmu;
}
