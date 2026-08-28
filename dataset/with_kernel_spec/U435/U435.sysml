package VaccineVialMonitorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def HeatDamageScore :> Real;
    attribute def DarknessLevel :> Real;

    part def VaccineVial {
        attribute currentTemp : TemperatureValue;
        
        part label : ThermochromicLabel;
        part calculator : ExposureCalculator;
        part evaluator : StatusEvaluator;
        
        flow tempFlow : TemperatureValue from currentTemp to calculator.temp;
        flow scoreFlow : HeatDamageScore from calculator.damageScore to evaluator.score;
        flow darknessFlow : DarknessLevel from evaluator.targetDarkness to label.targetDarkness;
    }

    part def ThermochromicLabel {
        attribute outerRingDarkness : DarknessLevel = 0.8;
        attribute innerSquareDarkness : DarknessLevel = 0.1;
        in targetDarkness : DarknessLevel;
        
        exhibit state labelStates {
            entry; then safe;
            state safe {
                entry assign innerSquareDarkness := 0.1;
            }
            accept when targetDarkness >= 0.4
                then caution;
            state caution {
                entry assign innerSquareDarkness := 0.5;
            }
            accept when targetDarkness >= outerRingDarkness
                then discard;
            state discard {
                entry assign innerSquareDarkness := 0.8;
            }
        }
    }

    part def ExposureCalculator {
        in temp : TemperatureValue;
        out damageScore : HeatDamageScore = 0.0;
        attribute safeTemp : TemperatureValue = 8 [degC];
        
        exhibit state calculatorStates {
            entry; then belowSafe;
            state belowSafe;
            accept when temp > safeTemp
                then aboveSafe;
            state aboveSafe {
                entry assign damageScore := damageScore + 1.0;
            }
            accept when temp <= safeTemp
                then belowSafe;
        }
    }

    part def StatusEvaluator {
        in score : HeatDamageScore;
        out targetDarkness : DarknessLevel;
        attribute cautionThreshold : HeatDamageScore = 50.0;
        attribute discardThreshold : HeatDamageScore = 100.0;
        
        exhibit state evaluatorStates {
            entry; then safe;
            state safe {
                entry assign targetDarkness := 0.1;
            }
            accept when score >= cautionThreshold
                then caution;
            state caution {
                entry assign targetDarkness := 0.5;
            }
            accept when score >= discardThreshold
                then discard;
            state discard {
                entry assign targetDarkness := 0.8;
            }
        }
    }

    requirement def VVMRequirements {
        subject vvm : VaccineVial;
        requirement Irreversibility {
            doc /* The color change on the label is permanent and irreversible. */
        }
        requirement StateIndication {
            doc /* The system provides Safe, Caution, and Discard states. */
        }
    }
}
