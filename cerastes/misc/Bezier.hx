

package cerastes.misc;

/*
Code from Danil on AGDG (ahn#1384)

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Assertions;

public class BezierLinear : MonoBehaviour
{
    private List<float> arcLengths;         // Arc lengths sampled along t, where space between is 1/steps
    private float totalArcLength = 0.0f;    // Approx total arclength
    [Range(25, 200)] public int steps = 100;                 // How many samples (more means better final distribution of points)

    [HideInInspector] public List<float> tSamples;      // The evenly spaced t samples of the curve
    [Range(3, 20)] public int tSampleSteps = 20;                     // How many samples do we want

    public bool takeLastSample = true;      // Take a sample at the end of the curve (turn off if you are chaining curves in spline)

    public Vector3 a;
    public Vector3 b;
    public Vector3 c;
    public Vector3 d;

    void Start()
    {
        ComputeLinearSpline();
    }

    void OnValidate()
    {
        if (tSampleSteps >= steps)
        {
            tSampleSteps = 3;
        }
    }

    /// <summary>
    /// Add curve to head
    /// </summary>
    public void AddCurve()
    {
        Debug.Log("Add curve");
    }

    public void ComputeLinearSpline()
    {
        ComputeArcLengths(a, b, c, d);
        ComputeTSamples(a, b, c, d);
    }

    private void ComputeArcLengths(Vector3 a, Vector3 b, Vector3 c, Vector3 d)
    {
        arcLengths = new List<float>();
        arcLengths.Add(0);

        Vector3 previous = Bezier.GetPoint(a, b, c, d, 0.0f);

        float inverseSteps = 1.0f / steps;
        float totalArcLength = 0.0f;

        for (int i=1; i<steps; i++)
        {
            float t = i * inverseSteps;

            Vector3 current = Bezier.GetPoint(a, b, c, d, t);

            float arcLength = Vector3.Distance(current, previous);
            totalArcLength += arcLength;

            arcLengths.Add(totalArcLength);

            previous = current;
        }

        this.totalArcLength = arcLengths[arcLengths.Count - 1];
    }

    private void ComputeTSamples(Vector3 a, Vector3 b, Vector3 c, Vector3 d)
    {
        tSamples = new List<float>();
        float tSampleStride = totalArcLength / (tSampleSteps-1);    // We will end one early as it is zero inclusive
        float tStride = 1.0f / (steps-1);

        tSamples.Add(0);    // First sample is at zero

        float previousArcLength = arcLengths[0];
        float targetArcLength = tSampleStride;  // Index 1

        while (targetArcLength < totalArcLength)    // Has more?
        {
            int arcIndex = 0;   // Steadily increase index (to skip already done space)
            while (arcIndex <arcLengths.Count-1)
            {
                float currentArcLength = arcLengths[arcIndex];
                float nextArcLength = arcLengths[arcIndex + 1];

                if (targetArcLength > currentArcLength && targetArcLength < nextArcLength)
                {
                    float t = arcIndex * tStride;
                    float tNext = t + tStride;

                    float ratioBetween = Ratio(currentArcLength, nextArcLength, targetArcLength);
                    float tDistance = tStride * ratioBetween;
                    float tResult = t + tDistance;

                    tSamples.Add(tResult);

                    break;  // Found, skip incrementing arcIndex in case next sample falls in same range
                }

                arcIndex++;
            }

            targetArcLength += tSampleStride;
        }

        if (takeLastSample)
        {
            tSamples.Add(1.0f);     // Last sample is at end of bezier
        }
    }

    /// <summary>
    /// Given a value between low and high returns how close it is in range of 0 to 1
    /// </summary>
    /// <param name="low"></param>
    /// <param name="high"></param>
    /// <param name="value"></param>
    /// <returns></returns>
    private static float Ratio(float low, float high, float value)
    {
        Assert.IsTrue(low <= value);
        Assert.IsTrue(value <= high);

         return (value - low) / (high - low);
    }

}

*/