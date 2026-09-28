using System.Collections;
using UnityEngine;

public class CameraAlternative : MonoBehaviour
{
	public Transform target;

	[Header("Distance & Scale")]
	public float baseDistance = 10f;

	public float maxDistance = 20f;

	public float minScale = 1f;

	public float maxScale = 8f;

	public float smoothTime = 0.3f;

	public Vector3 rotation = new Vector3(45f, 45f, 0f);

	public static CameraAlternative Instance;

	[Header("Game Over Zoom")]
	public float gameOverZoomDuration = 3f;

	[Header("Impact Screen Shake")]
	public bool enableImpactShake = true;

	[Tooltip("How long the camera shakes.")]
	public float shakeDuration = 0.25f;

	[Tooltip("How far the camera moves during the shake.")]
	public float shakeStrength = 0.4f;

	[Header("Debug Screen Shake")]
	public bool enableShakeDebug = true;

	[Tooltip("Press this key to test the screen shake.")]
	public KeyCode shakeDebugKey = KeyCode.K;

	[Tooltip("Debug shake duration. Used when pressing the debug key.")]
	public float debugShakeDuration = 0.25f;

	[Tooltip("Debug shake strength. Used when pressing the debug key.")]
	public float debugShakeStrength = 0.4f;

	[Header("Fog Settings")]
	public float baseFogStart = 5f;

	public float maxFogStart = 15f;

	public float baseFogEnd = 30f;

	public float maxFogEnd = 60f;

	[Header("Live Camera Effects")]
	public bool enableSway = true;

	public bool enableLiveZoom = true;

	public bool enablePanicZoom = true;

	public bool enableIdleZoomBoost = true;

	[Range(0f, 1f)]
	public float effectIntensity = 0.5f;

	[Header("Sway")]
	public float swayPositionAmount = 0.25f;

	public float swayRotationAmount = 0.6f;

	public float swaySpeed = 0.15f;

	[Header("Live Zoom")]
	public float liveZoomAmount = 1.2f;

	public float liveZoomSpeed = 0.1f;

	[Header("Idle Zoom Boost")]
	public float idleMovementThreshold = 0.05f;

	public float idleTimeBeforeBoost = 1.2f;

	public float idleZoomMultiplier = 2f;

	[Header("Panic Zoom")]
	public float panicZoomAmount = -3f;

	public float panicZoomInTime = 0.2f;

	public float panicZoomOutTime = 0.6f;

	private Vector3 offset;

	private float currentDistance;

	private float targetDistance;

	private float distanceVelocity;

	private Vector3 positionVelocity;

	private bool isGameOverZoom;

	private Vector3 frozenPosition;

	private Vector3 swayOffset;

	private Vector3 swayRotation;

	private float liveZoomOffset;

	private float panicZoomOffset;

	private float swaySeedX;

	private float swaySeedY;

	private float zoomSeed;

	private Vector3 lastTargetPosition;

	private float idleTimer;

	private float idleZoomFactor = 1f;

	private float shakeTimer;

	private float currentShakeStrength;

	public float CurrentDistance => currentDistance;

	private void OnEnable()
	{
		ShrinkPlayer.OnGameOver += HandleGameOver;
	}

	private void OnDisable()
	{
		ShrinkPlayer.OnGameOver -= HandleGameOver;
	}

	private void Awake()
	{
		Instance = this;
	}

	private void OnDestroy()
	{
		if (Instance == this)
		{
			Instance = null;
		}
	}

	private void Start()
	{
		if (target == null)
		{
			Debug.LogWarning("Target is not assigned for camera follow.");
			return;
		}
		currentDistance = baseDistance;
		targetDistance = currentDistance;
		RenderSettings.fog = true;
		RenderSettings.fogMode = FogMode.Linear;
		swaySeedX = Random.Range(0f, 1000f);
		swaySeedY = Random.Range(0f, 1000f);
		zoomSeed = Random.Range(0f, 1000f);
		lastTargetPosition = target.position;
	}

	private void Update()
	{
		if (enableShakeDebug && Input.GetKeyDown(shakeDebugKey))
		{
			TriggerImpactShake(debugShakeDuration, debugShakeStrength);
		}
	}

	public void TriggerImpactShake(float duration, float strength)
	{
		if (enableImpactShake && !isGameOverZoom)
		{
			duration = Mathf.Max(0.01f, duration);
			strength = Mathf.Max(0f, strength);
			shakeTimer = Mathf.Max(shakeTimer, duration);
			currentShakeStrength = Mathf.Max(currentShakeStrength, strength);
		}
	}

	private void LateUpdate()
	{
		if (!isGameOverZoom && target != null)
		{
			float t = Mathf.InverseLerp(minScale, maxScale, target.localScale.magnitude);
			targetDistance = Mathf.Lerp(baseDistance, maxDistance, t);
			RenderSettings.fogStartDistance = Mathf.Lerp(baseFogStart, maxFogStart, t);
			RenderSettings.fogEndDistance = Mathf.Lerp(baseFogEnd, maxFogEnd, t);
		}
		if (enableIdleZoomBoost && !isGameOverZoom && target != null)
		{
			if (Vector3.Distance(target.position, lastTargetPosition) < idleMovementThreshold)
			{
				idleTimer += Time.deltaTime;
			}
			else
			{
				idleTimer = 0f;
			}
			idleZoomFactor = ((idleTimer >= idleTimeBeforeBoost) ? idleZoomMultiplier : 1f);
			lastTargetPosition = target.position;
		}
		else
		{
			idleZoomFactor = 1f;
		}
		currentDistance = Mathf.SmoothDamp(currentDistance, targetDistance, ref distanceVelocity, smoothTime);
		float time = Time.time;
		swayOffset = Vector3.zero;
		swayRotation = Vector3.zero;
		liveZoomOffset = 0f;
		if (enableSway)
		{
			float num = Mathf.PerlinNoise(swaySeedX, time * swaySpeed) - 0.5f;
			float num2 = Mathf.PerlinNoise(swaySeedY, time * swaySpeed) - 0.5f;
			swayOffset = new Vector3(num, num2, 0f) * swayPositionAmount * effectIntensity;
			swayRotation = new Vector3(num2 * swayRotationAmount, num * swayRotationAmount, num * swayRotationAmount * 0.4f) * effectIntensity;
		}
		if (enableLiveZoom && !isGameOverZoom)
		{
			float num3 = Mathf.PerlinNoise(zoomSeed, time * liveZoomSpeed) - 0.5f;
			liveZoomOffset = num3 * liveZoomAmount * effectIntensity * idleZoomFactor;
		}
		offset = Quaternion.Euler(rotation) * new Vector3(0f, 0f, 0f - (currentDistance + liveZoomOffset + panicZoomOffset));
		Vector3 vector;
		if (isGameOverZoom)
		{
			vector = frozenPosition;
		}
		else
		{
			vector = ((target != null) ? target.position : transform.position);
		}
		Vector3 vector2 = vector + offset + swayOffset;
		if (shakeTimer > 0f)
		{
			shakeTimer -= Time.deltaTime;
			float num4 = Mathf.Clamp01(shakeTimer / Mathf.Max(shakeDuration, 0.01f));
			float num5 = currentShakeStrength * num4;
			Vector3 vector3 = Random.insideUnitSphere * num5;
			vector2 += vector3;
			if (shakeTimer <= 0f)
			{
				shakeTimer = 0f;
				currentShakeStrength = 0f;
			}
		}
		transform.position = Vector3.SmoothDamp(transform.position, vector2, ref positionVelocity, smoothTime);
		transform.rotation = Quaternion.Euler(rotation) * Quaternion.Euler(swayRotation);
	}

	public void TriggerPanicZoom()
	{
		if (enablePanicZoom && !isGameOverZoom)
		{
			StopCoroutine("PanicZoomRoutine");
			StartCoroutine(PanicZoomRoutine());
		}
	}

	private IEnumerator PanicZoomRoutine()
	{
		float elapsed = 0f;
		while (elapsed < panicZoomInTime)
		{
			elapsed += Time.deltaTime;
			float t = elapsed / panicZoomInTime;
			panicZoomOffset = Mathf.Lerp(0f, panicZoomAmount, Mathf.SmoothStep(0f, 1f, t));
			yield return null;
		}
		elapsed = 0f;
		while (elapsed < panicZoomOutTime)
		{
			elapsed += Time.deltaTime;
			float t2 = elapsed / panicZoomOutTime;
			panicZoomOffset = Mathf.Lerp(panicZoomAmount, 0f, Mathf.SmoothStep(0f, 1f, t2));
			yield return null;
		}
		panicZoomOffset = 0f;
	}

	private void HandleGameOver()
	{
		isGameOverZoom = true;
		frozenPosition = ((target != null) ? target.position : transform.position);
		target = null;
		StopAllCoroutines();
		shakeTimer = 0f;
		currentShakeStrength = 0f;
		StartCoroutine(SmoothZoomOut(maxDistance));
	}

	private IEnumerator SmoothZoomOut(float endDistance)
	{
		float startDistance = currentDistance;
		float elapsed = 0f;
		while (elapsed < gameOverZoomDuration)
		{
			elapsed += Time.deltaTime;
			float t = Mathf.SmoothStep(0f, 1f, elapsed / gameOverZoomDuration);
			targetDistance = Mathf.Lerp(startDistance, endDistance, t);
			yield return null;
		}
		targetDistance = endDistance;
	}
}
