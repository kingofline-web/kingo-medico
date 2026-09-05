<?php
/**
 * Plugin Name: KINGO Medico API
 * Description: Endpoint REST server-side per chat e account dell'app.
 * Version: 1.1.0
 */

if (!defined('ABSPATH')) exit;

/*
|--------------------------------------------------------------------------
| CONFIGURAZIONE
|--------------------------------------------------------------------------
| Manteniamo per ora il namespace esistente per non rompere la chat già
| collegata nell'app. Il nome/branding potrà essere cambiato più avanti.
*/

define('KINGO_MEDICO_API_NS', 'kingo-medico/v1');
define('KINGO_MEDICO_TOKEN_META', '_kingo_medico_auth_tokens');
define('KINGO_MEDICO_PLAN_META', '_kingo_medico_plan');

/*
|--------------------------------------------------------------------------
| ROTTE REST
|--------------------------------------------------------------------------
*/

add_action('rest_api_init', function () {

    // Chat esistente.
    register_rest_route(KINGO_MEDICO_API_NS, '/chat', [
        'methods'  => 'POST',
        'callback' => 'kingo_medico_chat',
        'permission_callback' => '__return_true',
    ]);

    // Registrazione account.
    register_rest_route(KINGO_MEDICO_API_NS, '/register', [
        'methods'  => 'POST',
        'callback' => 'kingo_medico_register',
        'permission_callback' => '__return_true',
    ]);

    // Accesso account.
    register_rest_route(KINGO_MEDICO_API_NS, '/login', [
        'methods'  => 'POST',
        'callback' => 'kingo_medico_login',
        'permission_callback' => '__return_true',
    ]);

    // Dati dell'utente autenticato.
    register_rest_route(KINGO_MEDICO_API_NS, '/me', [
        'methods'  => 'GET',
        'callback' => 'kingo_medico_me',
        'permission_callback' => '__return_true',
    ]);

    // Logout del dispositivo corrente.
    register_rest_route(KINGO_MEDICO_API_NS, '/logout', [
        'methods'  => 'POST',
        'callback' => 'kingo_medico_logout',
        'permission_callback' => '__return_true',
    ]);
});

/*
|--------------------------------------------------------------------------
| UTILITÀ ACCOUNT E SICUREZZA
|--------------------------------------------------------------------------
*/

function kingo_medico_json_error($message, $status = 400, $code = 'request_error') {
    return new WP_REST_Response([
        'success' => false,
        'code'    => $code,
        'message' => $message,
    ], $status);
}

function kingo_medico_client_ip() {
    $ip = isset($_SERVER['REMOTE_ADDR']) ? (string) $_SERVER['REMOTE_ADDR'] : 'unknown';
    return preg_replace('/[^0-9a-fA-F:\.]/', '', $ip) ?: 'unknown';
}

/**
 * Rate limit semplice per ridurre brute-force e abuso.
 */
function kingo_medico_rate_limit($bucket, $limit = 15, $window = 900) {
    $key = 'km_rl_' . md5($bucket . '|' . kingo_medico_client_ip());
    $data = get_transient($key);

    if (!is_array($data)) {
        $data = [
            'count' => 0,
            'reset' => time() + $window,
        ];
    }

    if ((int) $data['reset'] <= time()) {
        $data = [
            'count' => 0,
            'reset' => time() + $window,
        ];
    }

    $data['count'] = (int) $data['count'] + 1;

    $ttl = max(1, (int) $data['reset'] - time());
    set_transient($key, $data, $ttl);

    if ((int) $data['count'] > $limit) {
        return kingo_medico_json_error(
            'Troppi tentativi. Attendi qualche minuto e riprova.',
            429,
            'rate_limited'
        );
    }

    return true;
}

function kingo_medico_generate_username($email) {
    $base = 'sc_' . substr(hash('sha256', strtolower($email)), 0, 18);
    $username = $base;
    $n = 1;

    while (username_exists($username)) {
        $username = $base . '_' . $n;
        $n++;
    }

    return $username;
}

function kingo_medico_token_ttl() {
    // 30 giorni, modificabile in futuro con un filtro WordPress.
    return (int) apply_filters('kingo_medico_token_ttl', 30 * DAY_IN_SECONDS);
}

function kingo_medico_get_tokens($user_id) {
    $tokens = get_user_meta($user_id, KINGO_MEDICO_TOKEN_META, true);
    return is_array($tokens) ? $tokens : [];
}

function kingo_medico_save_tokens($user_id, array $tokens) {
    update_user_meta($user_id, KINGO_MEDICO_TOKEN_META, array_values($tokens));
}

function kingo_medico_prune_tokens(array $tokens) {
    $now = time();

    return array_values(array_filter($tokens, function ($item) use ($now) {
        return is_array($item)
            && !empty($item['hash'])
            && !empty($item['expires'])
            && (int) $item['expires'] > $now;
    }));
}

function kingo_medico_issue_token($user_id) {
    try {
        $plain = bin2hex(random_bytes(32));
    } catch (Throwable $e) {
        $plain = wp_generate_password(64, false, false);
    }

    $hash = hash('sha256', $plain);
    $now = time();
    $expires = $now + kingo_medico_token_ttl();

    $tokens = kingo_medico_prune_tokens(kingo_medico_get_tokens($user_id));

    $tokens[] = [
        'hash'    => $hash,
        'created' => $now,
        'expires' => $expires,
    ];

    // Massimo 5 dispositivi/sessioni attive per account.
    if (count($tokens) > 5) {
        $tokens = array_slice($tokens, -5);
    }

    kingo_medico_save_tokens($user_id, $tokens);

    return [
        'token'   => $plain,
        'hash'    => $hash,
        'expires' => $expires,
    ];
}

function kingo_medico_get_bearer_token(WP_REST_Request $request) {
    $header = trim((string) $request->get_header('authorization'));

    if ($header === '' && isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $header = trim((string) $_SERVER['HTTP_AUTHORIZATION']);
    }

    if ($header === '' && isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $header = trim((string) $_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
    }

    if (preg_match('/^Bearer\s+(.+)$/i', $header, $m)) {
        return trim($m[1]);
    }

    return '';
}

function kingo_medico_authenticate_request(WP_REST_Request $request) {
    $plain = kingo_medico_get_bearer_token($request);

    if ($plain === '') {
        return new WP_Error(
            'missing_token',
            'Sessione non valida. Accedi nuovamente.',
            ['status' => 401]
        );
    }

    $wanted_hash = hash('sha256', $plain);

    $users = get_users([
        'meta_key'     => KINGO_MEDICO_TOKEN_META,
        'meta_compare' => 'EXISTS',
        'fields'       => 'all',
        'number'       => 200,
    ]);

    foreach ($users as $user) {
        $tokens = kingo_medico_prune_tokens(
            kingo_medico_get_tokens($user->ID)
        );

        kingo_medico_save_tokens($user->ID, $tokens);

        foreach ($tokens as $item) {
            $stored_hash = isset($item['hash']) ? (string) $item['hash'] : '';

            if ($stored_hash !== '' && hash_equals($stored_hash, $wanted_hash)) {
                return [
                    'user'       => $user,
                    'token'      => $plain,
                    'token_hash' => $wanted_hash,
                ];
            }
        }
    }

    return new WP_Error(
        'invalid_token',
        'Sessione scaduta o non valida. Accedi nuovamente.',
        ['status' => 401]
    );
}

function kingo_medico_user_payload(WP_User $user) {
    $plan = (string) get_user_meta($user->ID, KINGO_MEDICO_PLAN_META, true);
    if ($plan === '') {
        $plan = 'FREE';
    }

    return [
        'id'    => (int) $user->ID,
        'email' => (string) $user->user_email,
        'name'  => (string) $user->display_name,
        'plan'  => strtoupper($plan),
    ];
}

/*
|--------------------------------------------------------------------------
| REGISTRAZIONE
|--------------------------------------------------------------------------
*/

function kingo_medico_register(WP_REST_Request $request) {
    $limited = kingo_medico_rate_limit('register', 10, 15 * MINUTE_IN_SECONDS);
    if ($limited !== true) {
        return $limited;
    }

    $email = sanitize_email((string) $request->get_param('email'));
    $password = (string) $request->get_param('password');
    $name = sanitize_text_field((string) $request->get_param('name'));
    $privacy_accepted = rest_sanitize_boolean(
        $request->get_param('privacy_accepted')
    );

    if ($email === '' || !is_email($email)) {
        return kingo_medico_json_error(
            'Inserisci un indirizzo email valido.',
            400,
            'invalid_email'
        );
    }

    if (strlen($password) < 8) {
        return kingo_medico_json_error(
            'La password deve contenere almeno 8 caratteri.',
            400,
            'weak_password'
        );
    }

    if (!$privacy_accepted) {
        return kingo_medico_json_error(
            'Per registrarti devi accettare l’informativa privacy.',
            400,
            'privacy_required'
        );
    }

    if (email_exists($email)) {
        return kingo_medico_json_error(
            'Esiste già un account con questa email. Usa ACCEDI.',
            409,
            'email_exists'
        );
    }

    $username = kingo_medico_generate_username($email);

    if ($name === '') {
        $local = strstr($email, '@', true);
        $name = $local ? sanitize_text_field($local) : 'Utente';
    }

    $user_id = wp_insert_user([
        'user_login'   => $username,
        'user_email'   => $email,
        'user_pass'    => $password,
        'display_name' => $name,
        'role'         => 'subscriber',
    ]);

    if (is_wp_error($user_id)) {
        return kingo_medico_json_error(
            'Non è stato possibile creare l’account. Riprova.',
            500,
            'registration_failed'
        );
    }

    update_user_meta($user_id, KINGO_MEDICO_PLAN_META, 'FREE');
    update_user_meta($user_id, '_kingo_medico_privacy_accepted_at', current_time('mysql', true));

    $user = get_user_by('id', $user_id);
    $issued = kingo_medico_issue_token($user_id);

    return new WP_REST_Response([
        'success'    => true,
        'message'    => 'Account creato correttamente.',
        'token'      => $issued['token'],
        'expires_at' => gmdate('c', $issued['expires']),
        'user'       => kingo_medico_user_payload($user),
    ], 201);
}

/*
|--------------------------------------------------------------------------
| LOGIN
|--------------------------------------------------------------------------
*/

function kingo_medico_login(WP_REST_Request $request) {
    $limited = kingo_medico_rate_limit('login', 15, 15 * MINUTE_IN_SECONDS);
    if ($limited !== true) {
        return $limited;
    }

    $email = sanitize_email((string) $request->get_param('email'));
    $password = (string) $request->get_param('password');

    if ($email === '' || $password === '') {
        return kingo_medico_json_error(
            'Inserisci email e password.',
            400,
            'missing_credentials'
        );
    }

    $user = get_user_by('email', $email);

    if (
        !$user instanceof WP_User ||
        !wp_check_password($password, $user->user_pass, $user->ID)
    ) {
        return kingo_medico_json_error(
            'Email o password non corretti.',
            401,
            'invalid_credentials'
        );
    }

    $issued = kingo_medico_issue_token($user->ID);

    return new WP_REST_Response([
        'success'    => true,
        'message'    => 'Accesso effettuato.',
        'token'      => $issued['token'],
        'expires_at' => gmdate('c', $issued['expires']),
        'user'       => kingo_medico_user_payload($user),
    ], 200);
}

/*
|--------------------------------------------------------------------------
| PROFILO / SESSIONE
|--------------------------------------------------------------------------
*/

function kingo_medico_me(WP_REST_Request $request) {
    $auth = kingo_medico_authenticate_request($request);

    if (is_wp_error($auth)) {
        return kingo_medico_json_error(
            $auth->get_error_message(),
            401,
            $auth->get_error_code()
        );
    }

    return new WP_REST_Response([
        'success' => true,
        'user'    => kingo_medico_user_payload($auth['user']),
    ], 200);
}

function kingo_medico_logout(WP_REST_Request $request) {
    $auth = kingo_medico_authenticate_request($request);

    if (is_wp_error($auth)) {
        return kingo_medico_json_error(
            $auth->get_error_message(),
            401,
            $auth->get_error_code()
        );
    }

    $user_id = (int) $auth['user']->ID;
    $wanted_hash = (string) $auth['token_hash'];

    $tokens = kingo_medico_prune_tokens(
        kingo_medico_get_tokens($user_id)
    );

    $tokens = array_values(array_filter($tokens, function ($item) use ($wanted_hash) {
        $stored_hash = isset($item['hash']) ? (string) $item['hash'] : '';
        return $stored_hash === '' || !hash_equals($stored_hash, $wanted_hash);
    }));

    kingo_medico_save_tokens($user_id, $tokens);

    return new WP_REST_Response([
        'success' => true,
        'message' => 'Disconnessione effettuata.',
    ], 200);
}

/*
|--------------------------------------------------------------------------
| CHAT AI - CODICE ESISTENTE MANTENUTO
|--------------------------------------------------------------------------
*/

function kingo_medico_chat(WP_REST_Request $request) {
    $message = sanitize_textarea_field((string) $request->get_param('message'));
    $history = $request->get_param('history');

    if ($message === '') {
        return new WP_REST_Response(['message' => 'Messaggio vuoto.'], 400);
    }

    $api_key = defined('KINGO_MEDICO_OPENAI_API_KEY')
        ? KINGO_MEDICO_OPENAI_API_KEY
        : getenv('KINGO_MEDICO_OPENAI_API_KEY');

    if (!$api_key) {
        return new WP_REST_Response([
            'message' => 'Il servizio AI non è ancora configurato sul server.'
        ], 503);
    }

    $input = [];

    if (is_array($history)) {
        foreach (array_slice($history, -12) as $item) {
            if (!is_array($item)) continue;

            $role = isset($item['role']) && $item['role'] === 'assistant'
                ? 'assistant'
                : 'user';

            $content = isset($item['content'])
                ? sanitize_textarea_field((string) $item['content'])
                : '';

            if ($content !== '') {
                $input[] = [
                    'role'    => $role,
                    'content' => $content,
                ];
            }
        }
    }

    $input[] = [
        'role'    => 'user',
        'content' => $message,
    ];

    $instructions = implode("\n", [
        'Sei KINGO Medico, assistente sanitario informativo in lingua italiana.',
        'Non presentare mai una risposta come diagnosi definitiva e non prescrivere o modificare terapie.',
        'Spiega in modo chiaro e prudente, evidenziando quando è opportuno contattare un medico.',
        'Se il contenuto suggerisce una possibile emergenza o sintomi potenzialmente gravi, dai priorità all’invito a contattare immediatamente i servizi di emergenza appropriati.',
        'Per esami e referti spiega i termini e i valori senza sostituirti al professionista sanitario.',
        'Fai domande di chiarimento solo quando servono davvero.',
    ]);

    $response = wp_remote_post('https://api.openai.com/v1/responses', [
        'timeout' => 60,
        'headers' => [
            'Authorization' => 'Bearer ' . $api_key,
            'Content-Type'  => 'application/json',
        ],
        'body' => wp_json_encode([
            'model'        => 'gpt-5.6',
            'instructions' => $instructions,
            'input'        => $input,
            'store'        => false,
        ]),
    ]);

    if (is_wp_error($response)) {
        return new WP_REST_Response([
            'message' => 'Errore di connessione al servizio AI.'
        ], 502);
    }

    $status = wp_remote_retrieve_response_code($response);
    $body = json_decode(wp_remote_retrieve_body($response), true);

    if ($status < 200 || $status >= 300) {
        return new WP_REST_Response([
            'message' => 'Il servizio AI ha restituito un errore.',
            'status'  => $status,
        ], 502);
    }

    $reply = '';

    if (isset($body['output']) && is_array($body['output'])) {
        foreach ($body['output'] as $output_item) {
            if (
                !isset($output_item['content']) ||
                !is_array($output_item['content'])
            ) {
                continue;
            }

            foreach ($output_item['content'] as $content_item) {
                if (
                    isset($content_item['type']) &&
                    $content_item['type'] === 'output_text' &&
                    isset($content_item['text'])
                ) {
                    $reply .= (string) $content_item['text'];
                }
            }
        }
    }

    $reply = trim($reply);

    if ($reply === '') {
        return new WP_REST_Response([
            'message' => 'KINGO non ha ricevuto una risposta valida.'
        ], 502);
    }

    return new WP_REST_Response([
        'reply' => $reply
    ], 200);
}
