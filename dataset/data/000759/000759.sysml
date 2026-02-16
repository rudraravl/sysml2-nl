package 'SengstakenBlakemoreSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def InflationCommand;
    attribute def DeflationCommand;
    attribute def BleedingStatus {
        attribute severity : String;
    }

    part def SengstakenBlakemoreTube {
        doc /* A triple-lumen medical device for emergency control of acute esophageal and gastric variceal hemorrhage 
               through mechanical tamponade via dual balloon compression. */

        part gastricBalloon : Balloon {
            attribute maxPressure : PressureValue = 60.0;
            attribute maxVolume : VolumeValue = 500.0;
            attribute currentPressure : PressureValue = 0.0;
            attribute currentVolume : VolumeValue = 0.0;
            attribute isInflated : Boolean = false;
        }

        part esophagealBalloon : Balloon {
            attribute maxPressure : PressureValue = 45.0;
            attribute maxVolume : VolumeValue = 200.0;
            attribute currentPressure : PressureValue = 0.0;
            attribute currentVolume : VolumeValue = 0.0;
            attribute isInflated : Boolean = false;
        }

        part gastricAspirationLumen : AspirationLumen {
            attribute innerDiameter : LengthValue = 4.5;
            attribute flowRate : VolumeFlowRateValue = 0.0;
        }

        part esophagealAspirationLumen : AspirationLumen {
            attribute innerDiameter : LengthValue = 3.5;
            attribute flowRate : VolumeFlowRateValue = 0.0;
        }

        part tubeBody : TubeBody {
            attribute totalLength : LengthValue = 1000.0;
            attribute outerDiameter : LengthValue = 20.0;
            attribute material : String = "medical-grade silicone";
        }

        port gastricBalloonPort : BalloonControlPort;
        port esophagealBalloonPort : BalloonControlPort;
        port gastricAspirationPort : AspirationPort;
        port esophagealAspirationPort : AspirationPort;

        connect gastricBalloonPort to gastricBalloon::controlPort;
        connect esophagealBalloonPort to esophagealBalloon::controlPort;
        connect gastricAspirationPort to gastricAspirationLumen::lumenPort;
        connect esophagealAspirationPort to esophagealAspirationLumen::lumenPort;
    }

    part def Balloon {
        attribute maxPressure : PressureValue;
        attribute maxVolume : VolumeValue;
        attribute currentPressure : PressureValue;
        attribute currentVolume : VolumeValue;
        attribute isInflated : Boolean;

        port controlPort : BalloonControlPort;

        perform action manageBalloonState {
            first start;
            then merge checkState;

            state balloonState {
                entry; then deflated;

                state deflated {
                    entry assign currentPressure := 0.0;
                    entry assign currentVolume := 0.0;
                    entry assign isInflated := false;
                }

                transition deflated_to_inflating
                    first deflated
                    accept cmd : InflationCommand
                    then inflating;

                state inflating {
                    do action inflate : InflateBalloon {
                        in targetPressure = maxPressure;
                        in targetVolume = maxVolume;
                        inout pressure = currentPressure;
                        inout volume = currentVolume;
                    }
                }

                transition inflating_to_inflated
                    first inflating
                    if currentPressure >= maxPressure * 0.9
                    then inflated;

                state inflated {
                    entry assign isInflated := true;
                    do action maintain : MaintainPressure {
                        in targetPressure = currentPressure;
                        inout pressure = currentPressure;
                    }
                }

                transition inflated_to_deflating
                    first inflated
                    accept cmd : DeflationCommand
                    then deflating;

                state deflating {
                    do action deflate : DeflateBalloon {
                        inout pressure = currentPressure;
                        inout volume = currentVolume;
                    }
                }

                transition deflating_to_deflated
                    first deflating
                    if currentPressure <= 5.0
                    then deflated;
            }

            then checkState;
        }
    }

    part def AspirationLumen {
        attribute innerDiameter : LengthValue;
        attribute flowRate : VolumeFlowRateValue;
        port lumenPort : AspirationPort;
    }

    part def TubeBody {
        attribute totalLength : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute material : String;
    }

    port def BalloonControlPort {
        attribute commandPressure : PressureValue;
        attribute actualPressure : PressureValue;
        attribute commandVolume : VolumeValue;
    }

    port def AspirationPort {
        attribute aspirationRate : VolumeFlowRateValue;
        attribute collectedVolume : VolumeValue;
    }

    action def InflateBalloon {
        in targetPressure : PressureValue;
        in targetVolume : VolumeValue;
        inout pressure : PressureValue;
        inout volume : VolumeValue;
    }

    action def MaintainPressure {
        in targetPressure : PressureValue;
        inout pressure : PressureValue;
    }

    action def DeflateBalloon {
        inout pressure : PressureValue;
        inout volume : VolumeValue;
    }

    action def MonitorBleeding {
        out bleedingStatus : BleedingStatus;
    }

    action def AspirateLumen {
        in duration : TimeValue;
        out collectedVolume : VolumeValue;
    }

    action def ControlVaricealBleeding {
        in initialBleedingStatus : BleedingStatus;
        out gastricPressureCmd : PressureValue;
        out esophagealPressureCmd : PressureValue;
        out hemostasisAchieved : Boolean;

        first start;
        then merge evaluateBleeding;

        then action monitor : MonitorBleeding {
            out currentStatus : BleedingStatus;
        }

        then decide;
            if monitor.currentStatus.severity == "severe" then applyFullCompression;
            if monitor.currentStatus.severity == "moderate" then applyPartialCompression;
            if monitor.currentStatus.severity == "controlled" then maintainCompression;
            if monitor.currentStatus.severity == "stopped" then releaseCompression;

        action applyFullCompression {
            then action inflateGastric {
                assign gastricPressureCmd := 60.0;
            }
            then action applyTraction;
            then action inflateEsophageal {
                assign esophagealPressureCmd := 45.0;
            }
            then action aspirateGastric : AspirateLumen {
                in duration = 30.0;
            }
            then action aspirateEsophageal : AspirateLumen {
                in duration = 30.0;
            }
        }
        then evaluateBleeding;

        action applyPartialCompression {
            assign gastricPressureCmd := 50.0;
            assign esophagealPressureCmd := 35.0;
        }
        then evaluateBleeding;

        action applyTraction {
            doc /* Apply gentle traction to anchor gastric balloon at gastroesophageal junction. */
        }

        action maintainCompression {
            assign gastricPressureCmd := gastricPressureCmd;
            assign esophagealPressureCmd := esophagealPressureCmd;
        }
        then evaluateBleeding;

        action releaseCompression {
            assign gastricPressureCmd := 0.0;
            assign esophagealPressureCmd := 0.0;
            assign hemostasisAchieved := true;
        }
        then done;
    }

    part sengstakenBlakemoreTubeSystem : SengstakenBlakemoreTube {
        perform action controlBleeding : ControlVaricealBleeding;
    }

    requirement def SafetyRequirement;
    requirement def EffectivenessRequirement;
    requirement def OperationalRequirement;

    requirement <'SBT-REQ-001'> gastricBalloonPressureLimit : SafetyRequirement {
        doc /* The gastric balloon pressure shall not exceed 60 mmHg to prevent gastric wall injury and perforation. */

        subject tube : SengstakenBlakemoreTube;

        require constraint {
            tube.gastricBalloon.currentPressure <= tube.gastricBalloon.maxPressure
        }
    }

    requirement <'SBT-REQ-002'> esophagealBalloonPressureLimit : SafetyRequirement {
        doc /* The esophageal balloon pressure shall not exceed 45 mmHg to prevent esophageal necrosis and ulceration. */

        subject tube : SengstakenBlakemoreTube;

        require constraint {
            tube.esophagealBalloon.currentPressure <= tube.esophagealBalloon.maxPressure
        }
    }

    requirement <'SBT-REQ-003'> bleedingControlEffectiveness : EffectivenessRequirement {
        doc /* The system shall achieve mechanical tamponade of bleeding esophageal and gastric varices through controlled dual balloon inflation. */

        subject tube : SengstakenBlakemoreTube;

        assume constraint {
            tube.gastricBalloon.isInflated and tube.esophagealBalloon.isInflated
        }

        require constraint {
            tube.gastricBalloon.currentPressure >= 50.0 and 
            tube.esophagealBalloon.currentPressure >= 35.0
        }
    }

    requirement <'SBT-REQ-004'> aspirationFunctionality : EffectivenessRequirement {
        doc /* The system shall provide continuous aspiration of gastric and esophageal contents to prevent pulmonary aspiration. */

        subject tube : SengstakenBlakemoreTube;

        require constraint {
            tube.gastricAspirationLumen.flowRate >= 0.0 and
            tube.esophagealAspirationLumen.flowRate >= 0.0
        }
    }

    requirement <'SBT-REQ-005'> gastricBalloonAnchoring : OperationalRequirement {
        doc /* The gastric balloon shall be inflated first and positioned to anchor at the gastroesophageal junction before esophageal balloon inflation. */

        subject tube : SengstakenBlakemoreTube;

        require constraint {
            tube.gastricBalloon.isInflated implies tube.gastricBalloon.currentVolume >= 250.0
        }
    }

    requirement <'SBT-REQ-006'> tractionApplication : OperationalRequirement {
        doc /* Gentle traction shall be applied to the tube after gastric balloon inflation to ensure proper positioning at the gastroesophageal junction. */

        subject tube : SengstakenBlakemoreTube;
    }

    requirement primaryFunction {
        doc /* The Sengstaken-Blakemore tube system shall control acute esophageal and gastric variceal hemorrhage 
               through mechanical tamponade via dual balloon compression while providing continuous aspiration 
               of gastric and esophageal contents to prevent aspiration and monitor bleeding. */

        require gastricBalloonPressureLimit;
        require esophagealBalloonPressureLimit;
        require bleedingControlEffectiveness;
        require aspirationFunctionality;
        require gastricBalloonAnchoring;
        require tractionApplication;
    }
}
