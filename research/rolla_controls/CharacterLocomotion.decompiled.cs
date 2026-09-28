using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem;
using UnityEngine.UI;

[RequireComponent(typeof(Rigidbody))]
public class CharacterLocomotion : MonoBehaviour
{
	[Header("UI")]
	[SerializeField]
	private GameObject pauseMenuUI;

	[SerializeField]
	private GameObject gameplayUI;

	[SerializeField]
	private GameObject defaultPauseButton;

	[Header("Character")]
	[SerializeField]
	private Animator animator;

	[SerializeField]
	private Rigidbody rb;

	[SerializeField]
	private Transform characterVisual;

	[SerializeField]
	private bool lookToMovementDirection = true;

	[Header("Movement")]
	[SerializeField]
	private float movementThreshold = 0.1f;

	[SerializeField]
	private string forwardAnimationVar = "Forward";

	[SerializeField]
	private string strafeAnimationVar = "Strafe";

	[SerializeField]
	private string horizontalGamepadAxis = "Horizontal";

	[SerializeField]
	private string verticalGamepadAxis = "Vertical";

	[Header("Movement Speeds")]
	[SerializeField]
	private float minScale = 1f;

	[SerializeField]
	private float maxScale = 9f;

	[SerializeField]
	private float minSpeed = 40f;

	[SerializeField]
	private float maxSpeed = 60f;

	[SerializeField]
	private float rotationSpeed = 12f;

	[Header("Boost")]
	[SerializeField]
	private float boostMultiplier = 1.5f;

	[SerializeField]
	private float boostDuration = 1f;

	[SerializeField]
	private float boostCooldown = 5f;

	[SerializeField]
	private ParticleSystem boostEffect;

	[SerializeField]
	private Image boostCooldownBar;

	private float cooldownTimer;

	private float boostTimer;

	[Header("Audio")]
	[SerializeField]
	private AudioSource audioSource;

	[SerializeField]
	private AudioClip movementSound;

	[SerializeField]
	private AudioClip dashSound;

	[SerializeField]
	private float minPitch = 0.5f;

	[SerializeField]
	private float maxPitch = 1f;

	[Header("Intro / Control Lock")]
	[SerializeField]
	private float introLockDuration;

	public bool controlsEnabled = true;

	[Header("Pause Lock")]
	[SerializeField]
	private float pauseLockDuration = 5f;

	private float pauseLockTimer;

	private bool isPaused;

	private bool isBoosting;

	private bool isCooldown;

	private Transform camTransform;

	private float currentWalkSpeed;

	private float smoothedWalkSpeed;

	private float speedSmoothVelocity;

	private float speedSmoothTime = 0.25f;

	private float permanentSpeedMultiplier = 1f;

	private float temporarySpeedMultiplier = 1f;

	private GameObject lastSelectedButton;

	private void Awake()
	{
		if (rb == null)
		{
			rb = GetComponent<Rigidbody>();
		}
		if (characterVisual == null)
		{
			characterVisual = transform;
		}
		camTransform = Camera.main.transform;
		if (audioSource == null)
		{
			audioSource = GetComponent<AudioSource>();
		}
		rb.freezeRotation = true;
		rb.interpolation = RigidbodyInterpolation.Extrapolate;
	}

	private void Start()
	{
		RecalculateCamera(Camera.main);
		if (introLockDuration > 0f)
		{
			StartCoroutine(EnableControlsAfterDelay(introLockDuration));
		}
		if (boostCooldownBar != null)
		{
			boostCooldownBar.fillAmount = 1f;
		}
	}

	private void Update()
	{
		if (pauseLockTimer < pauseLockDuration)
		{
			pauseLockTimer += Time.unscaledDeltaTime;
		}
		if (((Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame) || (Gamepad.current != null && Gamepad.current.startButton.wasPressedThisFrame)) && pauseLockTimer >= pauseLockDuration)
		{
			TogglePause();
		}
		if (!controlsEnabled)
		{
			return;
		}
		if ((Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.JoystickButton1)) && !isBoosting && !isCooldown)
		{
			StartCoroutine(Boost());
		}
		HandlePauseMenuSelection();
		if (isCooldown)
		{
			cooldownTimer -= Time.deltaTime;
		}
		if (boostCooldownBar != null)
		{
			if (isBoosting)
			{
				boostCooldownBar.fillAmount = Mathf.Clamp01(boostTimer / boostDuration);
			}
			else if (isCooldown)
			{
				boostCooldownBar.fillAmount = Mathf.Clamp01(1f - cooldownTimer / boostCooldown);
			}
			else
			{
				boostCooldownBar.fillAmount = 1f;
			}
		}
	}

	public void SetTemporarySpeedBoost(float multiplier)
	{
		temporarySpeedMultiplier = Mathf.Max(1f, multiplier);
		Debug.Log($"[CharacterLocomotion] Temporary speed multiplier set to x{temporarySpeedMultiplier}");
	}

	private void FixedUpdate()
	{
		if (!isPaused && controlsEnabled)
		{
			float axis = Input.GetAxis(horizontalGamepadAxis);
			float axis2 = Input.GetAxis(verticalGamepadAxis);
			Mathf.Clamp01(new Vector2(axis, axis2).magnitude);
			float x = characterVisual.localScale.x;
			float num = Mathf.Clamp(x, minScale, maxScale);
			float t = minScale / num;
			float target = Mathf.Lerp(minSpeed, maxSpeed, t);
			smoothedWalkSpeed = Mathf.SmoothDamp(smoothedWalkSpeed, target, ref speedSmoothVelocity, speedSmoothTime);
			currentWalkSpeed = smoothedWalkSpeed;
			currentWalkSpeed *= temporarySpeedMultiplier;
			if (isBoosting)
			{
				currentWalkSpeed *= boostMultiplier;
			}
			Vector3 cameraRelativeMovement = GetCameraRelativeMovement(axis, axis2);
			Vector3 linearVelocity = cameraRelativeMovement * currentWalkSpeed;
			linearVelocity.y = rb.linearVelocity.y;
			rb.linearVelocity = linearVelocity;
			bool flag = cameraRelativeMovement.magnitude > movementThreshold;
			HandleAnimations(axis, axis2);
			HandleAudio(flag, x);
			if (lookToMovementDirection & flag)
			{
				Quaternion b = Quaternion.LookRotation(cameraRelativeMovement);
				characterVisual.rotation = Quaternion.Slerp(characterVisual.rotation, b, rotationSpeed * Time.fixedDeltaTime);
			}
		}
	}

	private Vector3 GetCameraRelativeMovement(float horizontalInput, float verticalInput)
	{
		Vector3 forward = camTransform.forward;
		forward.y = 0f;
		forward.Normalize();
		Vector3 right = camTransform.right;
		right.y = 0f;
		right.Normalize();
		Vector3 result = right * horizontalInput + forward * verticalInput;
		if (result.magnitude > 1f)
		{
			result.Normalize();
		}
		return result;
	}

	private void HandleAnimations(float horizontalInput, float verticalInput)
	{
		if (!(animator == null))
		{
			animator.SetFloat(forwardAnimationVar, verticalInput);
			animator.SetFloat(strafeAnimationVar, horizontalInput);
		}
	}

	private void HandleAudio(bool moving, float playerScale)
	{
		if (audioSource == null || movementSound == null)
		{
			return;
		}
		if (moving)
		{
			if (!audioSource.isPlaying)
			{
				audioSource.clip = movementSound;
				audioSource.loop = true;
				audioSource.Play();
			}
			float t = Mathf.InverseLerp(maxScale, minScale, playerScale);
			audioSource.pitch = Mathf.Lerp(minPitch, maxPitch, t);
		}
		else if (audioSource.isPlaying)
		{
			audioSource.Stop();
		}
	}

	public void SetPermanentSpeedBoost(float multiplier)
	{
		permanentSpeedMultiplier = Mathf.Max(1f, multiplier);
		Debug.Log($"[CharacterLocomotion] Permanent speed multiplier set to x{permanentSpeedMultiplier}");
	}

	private IEnumerator Boost()
	{
		isBoosting = true;
		boostTimer = boostDuration;
		if (audioSource != null && dashSound != null)
		{
			audioSource.PlayOneShot(dashSound);
		}
		if (boostEffect != null)
		{
			boostEffect.Play();
		}
		while (boostTimer > 0f)
		{
			boostTimer -= Time.deltaTime;
			yield return null;
		}
		isBoosting = false;
		if (boostEffect != null)
		{
			boostEffect.Stop();
		}
		StartCoroutine(BoostCooldown());
	}

	private IEnumerator BoostCooldown()
	{
		isCooldown = true;
		cooldownTimer = boostCooldown;
		yield return new WaitForSeconds(boostCooldown);
		isCooldown = false;
		if (boostCooldownBar != null)
		{
			boostCooldownBar.fillAmount = 1f;
		}
	}

	public bool IsCharacterBoosting()
	{
		return isBoosting;
	}

	public void TogglePause()
	{
		Debug.Log("TogglePause called");
		isPaused = !isPaused;
		if (AudioMixerLowpassController.Instance != null)
		{
			AudioMixerLowpassController.Instance.SetPaused(isPaused);
		}
		Time.timeScale = ((!isPaused) ? 1 : 0);
		if (pauseMenuUI != null)
		{
			pauseMenuUI.SetActive(isPaused);
		}
		if (gameplayUI != null)
		{
			gameplayUI.SetActive(!isPaused);
		}
		Cursor.visible = true;
		Cursor.lockState = CursorLockMode.None;
		if (isPaused)
		{
			rb.linearVelocity = Vector3.zero;
			if (EventSystem.current != null && EventSystem.current.currentSelectedGameObject == null && defaultPauseButton != null)
			{
				EventSystem.current.SetSelectedGameObject(defaultPauseButton);
				lastSelectedButton = defaultPauseButton;
			}
		}
		else
		{
			lastSelectedButton = null;
		}
	}

	private void HandlePauseMenuSelection()
	{
		if (isPaused && !(EventSystem.current == null))
		{
			GameObject currentSelectedGameObject = EventSystem.current.currentSelectedGameObject;
			if (currentSelectedGameObject != null)
			{
				lastSelectedButton = currentSelectedGameObject;
			}
			if (currentSelectedGameObject == null && lastSelectedButton != null)
			{
				EventSystem.current.SetSelectedGameObject(lastSelectedButton);
			}
		}
	}

	private void RecalculateCamera(Camera cam)
	{
		if (cam != null)
		{
			camTransform = cam.transform;
		}
	}

	private IEnumerator EnableControlsAfterDelay(float delay)
	{
		controlsEnabled = false;
		yield return new WaitForSeconds(delay);
		controlsEnabled = true;
	}
}
