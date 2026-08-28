package OtoscopeModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ── Value types with units ──
    value def Voltage :> Real { unit "V" }
    value def Current :> Real { unit "A" }
    value def Power :> Real { unit "W" }
    value def LuminousFlux :> Real { unit "lm" }
    value def Magnification :> Real { unit "x" }
    value def BatteryCharge :> Real { unit "percent" }
    value def Length :> Real { unit "mm" }
    value def Angle :> Real { unit "deg" }
    value def Duration :> Real { unit "h" }
    value def Diopter :> Real { unit "diopter" }

    // ── Item definitions ──
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def LightBeam {
        attribute intensity : LuminousFlux;
        attribute wavelength : Real;
    }
    item def ReflectedLight {
        attribute intensity : LuminousFlux;
    }
    item def MagnifiedImage {
        attribute magnification : Magnification;
        attribute clarity : Real;
    }
    item def UserCommand {
        attribute commandType : String;
    }
    item def LowBatteryAlert;

    // ── Port definitions ──
    port def ElectricalPowerPort {
        out power : ElectricalPower;
    }
    port def LightOutPort {
        out beam : LightBeam;
    }
    port def ReflectedLightPort {
        out reflected : ReflectedLight;
    }
    port def ImagePort {
        out image : MagnifiedImage;
    }
    port def CommandPort {
        in command : UserCommand;
    }
    port def AlertPort {
        out alert : LowBatteryAlert;
    }

    // ── Requirements ──
    requirement def IlluminationRequirement {
        doc "The otoscope shall provide focused illumination of the ear canal."
        subject otoscope :> Otoscope
        objective {
            otoscope.head.led.intensity >= 100.0 [lm]
        }
    }

    requirement def MagnificationRequirement {
        doc "The optical system shall provide approximately 3.5x magnification."
        subject opticalSystem :> OpticalSystem
        objective {
            opticalSystem.magnification == 3.5 [x]
        }
    }

    requirement def BatteryLifeRequirement {
        doc "The battery shall support continuous examination for at least 2 hours."
        subject battery :> BatteryPack
        objective {
            battery.capacity >= 2000.0 [mAh]
        }
    }

    requirement def SafetyRequirement {
        doc "The otoscope shall warn the user and power down when battery is critically low."
        subject otoscope :> Otoscope
        objective {
            otoscope.lowBatteryWarning == true when otoscope.handle.battery.charge <= 15.0 [percent]
        }
    }

    requirement def ErgonomicRequirement {
        doc "The handle shall provide a comfortable grip for extended examinations."
        subject handle :> Handle
        objective {
            handle.ergonomic == true
        }
    }

    // ── Part: BatteryPack ──
    part def BatteryPack {
        attribute charge : BatteryCharge = 100.0 [percent];
        attribute capacity : Real = 2500.0 [mAh];
        attribute nominalVoltage : Voltage = 3.7 [V];
        attribute maxDischargeCurrent : Current = 1.5 [A];
        attribute rechargeable : Boolean = true;
        port out powerOut : ElectricalPowerPort;
        port out alertOut : AlertPort;

        action def Discharge {
            in amount : Real;
            out newCharge : BatteryCharge;
        }

        action def Recharge {
            in supplyVoltage : Voltage;
            out restoredCharge : BatteryCharge;
        }

        state def BatteryHealthStates {
            entry;
            state normal;
            state low {
                entry { send LowBatteryAlert; }
            }
            state critical;
            transition normal to low when charge <= 15.0 [percent];
            transition low to critical when charge <= 5.0 [percent];
        }

        exhibit BatteryHealthStates;
    }

    // ── Part: LEDBulb ──
    part def LEDBulb {
        attribute intensity : LuminousFlux = 120.0 [lm];
        attribute colorTemp : Real = 6500.0;
        attribute lifespan : Duration = 50000.0 [h];
        attribute powerDraw : Power = 0.5 [W];
        port in powerIn : ElectricalPowerPort;
        port out lightOut : LightOutPort;

        action def Illuminate {
            in p : ElectricalPower;
            out b : LightBeam;
        }
    }

    // ── Part: Speculum ──
    part def Speculum {
        attribute length : Length = 25.0 [mm];
        attribute coneAngle : Angle = 30.0 [deg];
        attribute detachable : Boolean = true;
        attribute sterile : Boolean = true;
        port light : LightOutPort;
        port reflected : ReflectedLightPort;

        action def DirectLight {
            in incoming : LightBeam;
            out outgoing : LightBeam;
        }

        action def CollectReflected {
            in raw : ReflectedLight;
            out collected : ReflectedLight;
        }
    }

    // ── Part: Lens ──
    part def Lens {
        attribute focalLength : Length;
        attribute diameter : Length;
    }

    // ── Part: OpticalSystem ──
    part def OpticalSystem {
        attribute magnification : Magnification = 3.5 [x];
        attribute fieldOfView : Angle = 45.0 [deg];
        part objectiveLens : Lens {
            attribute focalLength = 20.0 [mm];
            attribute diameter = 8.0 [mm];
        }
        part relayLens : Lens {
            attribute focalLength = 15.0 [mm];
            attribute diameter = 6.0 [mm];
        }
        port in reflectedIn : ReflectedLightPort;
        port out imageOut : ImagePort;

        action def Magnify {
            in reflected : ReflectedLight;
            out image : MagnifiedImage;
        }
    }

    // ── Part: Eyepiece ──
    part def Eyepiece {
        attribute focusAdjustable : Boolean = true;
        attribute diopterMin : Diopter = -5.0 [diopter];
        attribute diopterMax : Diopter = 5.0 [diopter];
        attribute currentFocus : Diopter = 0.0 [diopter];
        port in imageIn : ImagePort;

        action def Focus {
            in image : MagnifiedImage;
            in focusSetting : Diopter;
            out focusedImage : MagnifiedImage;
        }
    }

    // ── Part: Handle ──
    part def Handle {
        attribute ergonomic : Boolean = true;
        attribute material : String = "Medical-grade ABS";
        attribute length : Length = 120.0 [mm];
        attribute gripDiameter : Length = 28.0 [mm];
        part battery : BatteryPack;
        port out powerPort : ElectricalPowerPort;
    }

    // ── Part: HeadAssembly ──
    part def HeadAssembly {
        attribute attachmentType : String = "Bayonet";
        part led : LEDBulb;
        part speculum : Speculum;
        part optics : OpticalSystem;
        part eyepiece : Eyepiece;
        port in powerIn : ElectricalPowerPort;
        port in commandIn : CommandPort;
    }

    // ── Part: PowerButton ──
    part def PowerButton {
        attribute pressed : Boolean = false;
        port out command : CommandPort;

        action def Press {
            out cmd : UserCommand;
        }
    }

    // ── Part: IlluminationSwitch ──
    part def IlluminationSwitch {
        attribute pressed : Boolean = false;
        port out command : CommandPort;

        action def Toggle {
            out cmd : UserCommand;
        }
    }

    // ── Part: Otoscope (top-level) ──
    part def Otoscope {
        attribute lowBatteryWarning : Boolean = false;
        attribute autoShutdownEnabled : Boolean = true;
        attribute manufacturer : String = "MediScope Inc.";
        attribute model : String = "OS-3500";

        part handle : Handle {
            part battery : BatteryPack;
        }
        part head : HeadAssembly;
        part powerButton : PowerButton;
        part illumSwitch : IlluminationSwitch;

        satisfy IlluminationRequirement;
        satisfy MagnificationRequirement;
        satisfy BatteryLifeRequirement;
        satisfy SafetyRequirement;
        satisfy ErgonomicRequirement;

        port commandPort : CommandPort;
        port alertPort : AlertPort;

        // ── State machine ──
        state def OtoscopeStates {
            entry;
            state powerOff {
                entry { /* device fully off */ }
            }
            state standby {
                entry { /* device on, light inactive */ }
            }
            state examining {
                entry { /* illumination active */ }
            }

            transition powerOff to standby
                when powerButton.pressed == true
                and handle.battery.charge > 5.0 [percent];

            transition standby to examining
                when illumSwitch.pressed == true;

            transition examining to standby
                when illumSwitch.pressed == false;

            transition standby to powerOff
                when powerButton.pressed == false;

            transition examining to standby
                when handle.battery.charge <= 15.0 [percent];

            transition standby to powerOff
                when handle.battery.charge <= 5.0 [percent];

            transition examining to powerOff
                when handle.battery.charge <= 5.0 [percent];
        }

        exhibit OtoscopeStates;

        // ── Internal actions ──
        action def PowerOnSequence {
            in cmd : UserCommand;
            out status : String;
        }

        action def AutoShutdown {
            in trigger : LowBatteryAlert;
            out shutdownCmd : UserCommand;
        }
    }

    // ── Instantiated system with connections ──
    part otoscopeInstance : Otoscope {
        // Battery supplies power to LED
        connect handle.battery.powerOut to head.led.powerIn;

        // LED light directed into speculum
        connect head.led.lightOut to head.speculum.light;

        // Reflected light from speculum to optical system
        connect head.speculum.reflected to head.optics.reflectedIn;

        // Magnified image from optics to eyepiece
        connect head.optics.imageOut to head.eyepiece.imageIn;

        // Power button command to head
        connect powerButton.command to head.commandIn;

        // Illumination switch command to head
        connect illumSwitch.command to head.commandIn;

        // Battery alert to otoscope alert port
        connect handle.battery.alertOut to alertPort;

        // Handle power port to head power input
        connect handle.powerPort to head.powerIn;
    }
}
