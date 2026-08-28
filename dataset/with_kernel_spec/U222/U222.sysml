package MedicalEyepatchSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def LightTransmission :> Real {
            doc /* Percentage of incoming light transmitted through the pad. */
        }
        attribute def PressureValue :> Real;
        attribute def LengthValue :> Real;
        attribute def TensionValue :> Real;
        attribute def CoverageAreaValue :> Real;
        
        attribute def FitSignal;
        attribute def RemoveSignal;
        attribute def ReadjustSignal;
        attribute def SecureSignal;
        
        port def PadToCushionPort {
            in pressure : PressureValue;
        }
        port def CushionToSkinPort {
            out contactPressure : PressureValue;
        }
        port def StrapToPadPort {
            in tension : TensionValue;
        }
        port def AmbientLightPort {
            in incomingLight : Real;
            out transmittedLight : Real;
        }
        
        part def OcclusivePad {
            attribute minLightBlocking : LightTransmission = 98.0;
            attribute coverageArea : CoverageAreaValue;
            attribute lightTransmission : LightTransmission;
            attribute thickness : LengthValue;
            port ambientLightPort : AmbientLightPort;
            port cushionInterface : PadToCushionPort;
            port strapInterface : StrapToPadPort;
            assert constraint {
                lightTransmission <= (100.0 - minLightBlocking)
            }
            perform action blockLight : BlockLight;
            perform action distributePressure : DistributePressure;
        }
        
        part def CushionLayer {
            attribute targetPressure : PressureValue;
            attribute breathability : Real;
            attribute softness : Real;
            port padInterface : PadToCushionPort;
            port skinInterface : CushionToSkinPort;
            perform action distributePressure : DistributePressure;
            perform action senseComfort : SenseComfort;
        }
        
        part def AdjustableStrap {
            attribute minLength : LengthValue;
            attribute maxLength : LengthValue;
            attribute currentLength : LengthValue;
            attribute targetTension : TensionValue;
            attribute elasticity : Real;
            attribute durability : Real;
            port padInterface : StrapToPadPort;
            assert constraint {
                currentLength >= minLength and currentLength <= maxLength
            }
            perform action adjustLength : AdjustLength;
            perform action applyTension : ApplyTension;
        }
        
        part def Wearer {
            attribute headCircumference : LengthValue;
            attribute skinSensitivity : Real;
        }
        
        part def MedicalEyepatch {
            attribute maxWearDuration : Real;
            port lightPort : AmbientLightPort;
            port skinPort : CushionToSkinPort;
            part occlusivePad : OcclusivePad;
            part cushionLayer : CushionLayer;
            part adjustableStrap : AdjustableStrap;
            connect occlusivePad.ambientLightPort to lightPort;
            connect occlusivePad.cushionInterface to cushionLayer.padInterface;
            connect cushionLayer.skinInterface to skinPort;
            connect adjustableStrap.padInterface to occlusivePad.strapInterface;
            perform action protectEye : ProtectEye;
            perform action fitDevice : FitDevice;
            perform action removeDevice : RemoveDevice;
            exhibit state eyepatchStates : EyepatchStates;
        }
        
        action def BlockLight {
            in incomingLight : Real;
            out transmittedLight : Real;
        }
        action def DistributePressure {
            in pressure : PressureValue;
            out distributedPressure : PressureValue;
        }
        action def SenseComfort {
            out comfortLevel : Real;
            out fitStatus : Real;
        }
        action def AdjustLength {
            in desiredLength : LengthValue;
            out tension : TensionValue;
        }
        action def ApplyTension {
            in tension : TensionValue;
            out appliedTension : TensionValue;
        }
        action def ProtectEye {
            doc /* Continuously blocks light and prevents physical contact. */
        }
        action def FitDevice {
            doc /* Position pad over eye and adjust strap. */
            in headCircumference : LengthValue;
            out tension : TensionValue;
        }
        action def RemoveDevice {
            doc /* Remove eyepatch and return to idle. */
        }
        
        state def EyepatchStates;
        
        requirement def LightBlockingRequirement {
            doc /* The occlusive pad shall block at least 98% of incoming ambient light. */
            attribute minBlockingPercent : LightTransmission = 98.0;
            subject pad : OcclusivePad;
            assert constraint {
                pad.lightTransmission <= (100.0 - minBlockingPercent)
            }
        }
        
        requirement def ComfortRequirement {
            doc /* The cushion layer shall distribute pressure evenly to prevent discomfort. */
            subject cushion : CushionLayer;
            assert constraint {
                cushion.targetPressure <= 5.0
            }
        }
        
        requirement def StrapFitRequirement {
            doc /* The adjustable strap shall fit a range of head sizes and maintain tension. */
            subject strap : AdjustableStrap;
            assert constraint {
                strap.minLength <= strap.currentLength and
                strap.currentLength <= strap.maxLength
            }
        }
        
        requirement def CoverageRequirement {
            doc /* The occlusive pad shall provide full coverage of the eye socket. */
            subject pad : OcclusivePad;
            assert constraint {
                pad.coverageArea >= 1000.0
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        action blockLight : BlockLight;
        action distributePressure : DistributePressure;
        action senseComfort : SenseComfort;
        action adjustLength : AdjustLength;
        action applyTension : ApplyTension;
        action protectEye : ProtectEye;
        action fitDevice : FitDevice;
        action removeDevice : RemoveDevice;
        
        part eyepatch : MedicalEyepatch {
            part occlusivePad : OcclusivePad {
                :>> lightTransmission = 1.5;
                :>> thickness = 8.0;
                :>> coverageArea = 1200.0;
            }
            part cushionLayer : CushionLayer {
                :>> breathability = 0.9;
                :>> softness = 0.95;
                :>> targetPressure = 3.0;
            }
            part adjustableStrap : AdjustableStrap {
                :>> elasticity = 0.85;
                :>> durability = 0.9;
                :>> minLength = 400.0;
                :>> maxLength = 700.0;
                :>> currentLength = 550.0;
                :>> targetTension = 2.5;
            }
        }
        
        part wearer : Wearer {
            :>> headCircumference = 560.0;
            :>> skinSensitivity = 0.7;
        }
        
        state eyepatchStates : EyepatchStates {
            entry; then idle;
            
            state idle;
            accept FitSignal
                then fitting;
            
            state fitting {
                entry adjustLength;
                do applyTension;
            }
            accept SecureSignal
                then active;
            
            state active {
                entry protectEye;
                do blockLight;
                do distributePressure;
                do senseComfort;
            }
            accept ReadjustSignal
                then fitting;
            accept RemoveSignal
                then idle;
        }
        
        satisfy LightBlockingRequirement by eyepatch.occlusivePad;
        satisfy ComfortRequirement by eyepatch.cushionLayer;
        satisfy StrapFitRequirement by eyepatch.adjustableStrap;
        satisfy CoverageRequirement by eyepatch.occlusivePad;
    }
}
